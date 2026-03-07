# Unit Testing — Java / Spring Boot

Patterns for testing a layered Spring Boot application. Each layer gets the right tool: fast, focused, no unnecessary Spring context.

**Reference:** [nicograef/lexiban @ 816e66b](https://github.com/nicograef/lexiban/tree/816e66b9b8645e8efada08fdf1e41dbeb96cb0da) — all patterns below are taken from that project.

---

## Test Strategy per Layer

| Layer | Tool | What it tests |
| ----- | ---- | ------------- |
| Controller | `@WebMvcTest` + `MockMvc` | HTTP contract (status codes, JSON shape, validation) |
| Service | `@ExtendWith(MockitoExtension.class)` | Orchestration logic, call order, caching, fallback chains |
| Value Object / Algorithm | Plain JUnit 5 | Pure logic, normalization, structural validation |
| HTTP Client | `MockRestServiceServer` | Outbound HTTP calls — no real network |

**Rule:** test only public, observable behavior. Never test private methods directly.

---

## Controller Tests — `@WebMvcTest`

Loads only the web layer. No database, no full Spring context. Mock every downstream dependency.

```java
@WebMvcTest(IbanController.class)
class IbanControllerTest {

    @Autowired MockMvc mockMvc;

    @MockitoBean IbanService ibanService;          // Spring replaces real bean with mock
    @MockitoBean IbanRepository ibanRepository;   // Spring replaces real bean with mock

    @Test
    void validIbanReturnsOk() throws Exception {
        when(ibanService.validateOrLookup(anyString()))
                .thenReturn(new ValidationResult(true, "DE89370400440532013000", "Commerzbank", null));

        mockMvc.perform(
                        post("/api/ibans")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"iban\": \"DE89370400440532013000\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(true))
                .andExpect(jsonPath("$.bankName").value("Commerzbank"));
    }

    @Test
    void emptyBodyReturnsBadRequest() throws Exception {
        mockMvc.perform(
                        post("/api/ibans")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"iban\": \"\"}"))
                .andExpect(status().isBadRequest());
    }
}
```

**Why `@WebMvcTest` over `@SpringBootTest`:**
- Only MVC layer loads → significantly faster
- Forces mocking of services → tests HTTP contract in isolation
- `@MockitoBean` replaces the real bean in the Spring context; `@Mock` does not

---

## Service Tests — Mockito

Pure unit tests. No Spring context. Construct the service manually to keep dependencies explicit.

```java
@ExtendWith(MockitoExtension.class)
class IbanServiceTest {

    @Mock LocalIbanValidator localValidator;
    @Mock OpenIbanValidator openIbanValidator;
    @Mock IbanRepository ibanRepository;

    private IbanService service;

    @BeforeEach
    void setUp() {
        service = new IbanService(localValidator, openIbanValidator, ibanRepository);
    }

    @Test
    void returnsCachedResultWithoutCallingValidators() {
        Iban cached = new Iban("DE89370400440532013000", "Commerzbank", true, null);
        when(ibanRepository.findById("DE89370400440532013000")).thenReturn(Optional.of(cached));

        var result = service.validateOrLookup("DE89370400440532013000");

        assertTrue(result.valid());
        verify(localValidator, never()).validate(any());   // cache hit — validators never called
        verify(openIbanValidator, never()).validate(any());
        verify(ibanRepository, never()).save(any());
    }

    @Test
    void localInvalidStopsChain() {
        when(ibanRepository.findById(any())).thenReturn(Optional.empty());
        when(localValidator.validate(any()))
                .thenReturn(Optional.of(new ValidationResult(false, "DE00...", null, "Bad checksum")));

        service.validateOrLookup("DE00370400440532013000");

        verify(openIbanValidator, never()).validate(any()); // chain stopped — no external call
    }
}
```

**Constructor injection** is required here: `@Autowired` field injection cannot be replicated without a Spring context — constructor injection allows `new Service(mock1, mock2)` in tests.

---

## Parameterized Tests

For algorithms or validation logic with many input cases — avoids copy-paste test methods.

```java
@ParameterizedTest
@ValueSource(strings = {
    "DE89370400440532013000",   // Germany (22 chars)
    "NO9386011117947",          // Norway (shortest: 15 chars)
    "MT84MALT011000012345MTLCAST001S"  // Malta (longest: 31 chars)
})
void validIbans(String iban) {
    assertTrue(validator.isValid(iban));
}

@ParameterizedTest
@NullSource
@ValueSource(strings = {"", "DE89", "DE89370400440532013000EXTRA"})
void rejectsInvalidInput(String input) {
    assertThrows(IbanFormatException.class, () -> new IbanNumber(input));
}
```

Combine `@NullSource` + `@ValueSource` to cover `null` and blank/malformed inputs in one sweep.

---

## HTTP Client Tests — `MockRestServiceServer`

Intercepts `RestClient` / `RestTemplate` calls without a real network.

```java
class OpenIbanValidatorTest {

    private MockRestServiceServer mockServer;
    private OpenIbanValidator validator;

    @BeforeEach
    void setUp() {
        var builder = RestClient.builder();
        mockServer = MockRestServiceServer.bindTo(builder).build();
        validator = new OpenIbanValidator(builder);  // inject the intercepted builder
    }

    @Test
    void validIbanWithBankData() {
        mockServer
                .expect(requestTo(OpenIbanValidator.BASE_URL + "DE89370400440532013000?getBIC=true&validateBankCode=true"))
                .andRespond(withSuccess("""
                        {"valid": true, "bankData": {"name": "Commerzbank"}}
                        """, MediaType.APPLICATION_JSON));

        var result = validator.validate(new IbanNumber("DE89370400440532013000"));

        assertTrue(result.get().valid());
        assertEquals("Commerzbank", result.get().bankName());
        mockServer.verify();  // assert the expected request was actually made
    }

    @Test
    void apiErrorReturnsEmpty() {
        mockServer
                .expect(requestTo(OpenIbanValidator.BASE_URL + "DE89370400440532013000?getBIC=true&validateBankCode=true"))
                .andRespond(withServerError());

        var result = validator.validate(new IbanNumber("DE89370400440532013000"));

        assertTrue(result.isEmpty());
        mockServer.verify();
    }
}
```

Always call `mockServer.verify()` — confirms the expected HTTP call was made.

---

## Value Object Tests — `assertAll`

Group related assertions so all failures are visible at once (not just the first one).

```java
@Test
void derivedProperties() {
    var iban = new IbanNumber("DE89370400440532013000");
    assertAll(
            () -> assertEquals("DE", iban.countryCode()),
            () -> assertEquals("89", iban.checkDigits()),
            () -> assertEquals("37040044", iban.bankIdentifier().orElseThrow()),
            () -> assertEquals("DE89 3704 0044 0532 0130 00", iban.formatted()));
}

@Test
void equalityByValueAfterNormalization() {
    assertEquals(
            new IbanNumber("DE89 3704 0044 0532 0130 00"),
            new IbanNumber("de89370400440532013000"));
}
```

---

## Naming & Structure

```
src/
  main/java/com/example/service/IbanService.java
  test/java/com/example/service/IbanServiceTest.java   ← same package, same name + "Test"
```

Test method names describe the scenario and expected outcome:

```java
returnsCachedResultWithoutCallingValidators()
localInvalidStopsChain()
apiErrorReturnsEmpty()
rejectsInvalidInput()
```

---

## Rules of Thumb

- **One test class per production class**, same package structure in `src/test`
- **Test public API only** — if you need to test a private method, extract it into a new class
- **`@MockitoBean`** in `@WebMvcTest`; **`@Mock` + manual constructor** in plain unit tests
- **Constructor injection** everywhere — makes services testable without Spring
- **`./mvnw verify`** runs Spotless + Checkstyle + all tests — single CI command
