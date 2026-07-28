import Testing
@testable import iActivity

struct TemperatureUnitTests {
    @Test("Celsius passes through unchanged")
    func celsiusPassesThrough() {
        #expect(TemperatureUnit.celsius.string(fromCelsius: 36.6) == "36.6°C")
    }

    @Test("Zero Celsius converts to 32 Fahrenheit")
    func zeroCelsiusConvertsTo32Fahrenheit() {
        #expect(TemperatureUnit.fahrenheit.string(fromCelsius: 0) == "32.0°F")
    }

    @Test("100 Celsius converts to 212 Fahrenheit")
    func boilingPointConverts() {
        #expect(TemperatureUnit.fahrenheit.string(fromCelsius: 100) == "212.0°F")
    }

    @Test("-40 is the fixed point where Celsius and Fahrenheit agree")
    func negativeFortyIsFixedPoint() {
        #expect(TemperatureUnit.fahrenheit.string(fromCelsius: -40) == "-40.0°F")
    }

    @Test("decimals: 0 omits the fractional part")
    func zeroDecimalsOmitsFraction() {
        #expect(TemperatureUnit.celsius.string(fromCelsius: 55.7, decimals: 0) == "56°C")
    }

    @Test("Negative sensor readings (e.g. an unplugged/faulty sensor) don't crash formatting")
    func negativeCelsiusDoesNotCrash() {
        let result = TemperatureUnit.celsius.string(fromCelsius: -1)
        #expect(result == "-1.0°C")
    }
}
