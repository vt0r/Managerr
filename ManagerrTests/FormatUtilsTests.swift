import Testing
@testable import Managerr

struct FormatUtilsTests {

    // MARK: - eta

    @Test func eta_nil_returnsDash() {
        #expect(FormatUtils.eta(nil) == "—")
    }

    @Test func eta_zero_returnsDash() {
        #expect(FormatUtils.eta(0) == "—")
    }

    @Test func eta_negative_returnsDash() {
        #expect(FormatUtils.eta(-1) == "—")
    }

    @Test func eta_lessThanOneMinute_returnsZeroMinutes() {
        #expect(FormatUtils.eta(59) == "0m")
    }

    @Test func eta_exactlyOneMinute_returns1m() {
        #expect(FormatUtils.eta(60) == "1m")
    }

    @Test func eta_90seconds_returns1m() {
        #expect(FormatUtils.eta(90) == "1m")
    }

    @Test func eta_multipleMinutes_returnsMinutesOnly() {
        #expect(FormatUtils.eta(3599) == "59m")
    }

    @Test func eta_exactlyOneHour_returns1h0m() {
        #expect(FormatUtils.eta(3600) == "1h 0m")
    }

    @Test func eta_1h1m_formatsCorrectly() {
        #expect(FormatUtils.eta(3661) == "1h 1m")
    }

    @Test func eta_2h2m_formatsCorrectly() {
        #expect(FormatUtils.eta(7322) == "2h 2m")
    }

    // MARK: - percentage

    @Test func percentage_nil_returnsZeroPercent() {
        #expect(FormatUtils.percentage(nil) == "0%")
    }

    @Test func percentage_zero_returnsZeroPercent() {
        #expect(FormatUtils.percentage(0.0) == "0%")
    }

    @Test func percentage_quarter_returns25Percent() {
        #expect(FormatUtils.percentage(0.25) == "25%")
    }

    @Test func percentage_half_returns50Percent() {
        #expect(FormatUtils.percentage(0.5) == "50%")
    }

    @Test func percentage_full_returns100Percent() {
        #expect(FormatUtils.percentage(1.0) == "100%")
    }

    @Test func percentage_truncatesNotRounds() {
        // 0.999 → Int(99.9) → 99, not 100
        #expect(FormatUtils.percentage(0.999) == "99%")
    }

    // MARK: - trackDuration

    @Test func trackDuration_nil_returnsDash() {
        #expect(FormatUtils.trackDuration(nil) == "—")
    }

    @Test func trackDuration_zero_returnsDash() {
        #expect(FormatUtils.trackDuration(0) == "—")
    }

    @Test func trackDuration_negative_returnsDash() {
        #expect(FormatUtils.trackDuration(-500) == "—")
    }

    @Test func trackDuration_1second_formatsCorrectly() {
        #expect(FormatUtils.trackDuration(1_000) == "0:01")
    }

    @Test func trackDuration_30seconds_formatsCorrectly() {
        #expect(FormatUtils.trackDuration(30_000) == "0:30")
    }

    @Test func trackDuration_1minute_formatsCorrectly() {
        #expect(FormatUtils.trackDuration(60_000) == "1:00")
    }

    @Test func trackDuration_1min30sec_formatsCorrectly() {
        #expect(FormatUtils.trackDuration(90_000) == "1:30")
    }

    @Test func trackDuration_over60min_formatsWithoutHours() {
        // 61 minutes 1 second → "61:01" (no hours component)
        #expect(FormatUtils.trackDuration(3_661_000) == "61:01")
    }

    // MARK: - speed

    @Test func speed_alwaysEndsWithPerSecond() {
        #expect(FormatUtils.speed(0).hasSuffix("/s"))
        #expect(FormatUtils.speed(512_000).hasSuffix("/s"))
        #expect(FormatUtils.speed(10_000_000).hasSuffix("/s"))
    }

    // MARK: - fileSize

    @Test func fileSize_returnsNonEmptyString() {
        #expect(!FormatUtils.fileSize(0).isEmpty)
        #expect(!FormatUtils.fileSize(1_024).isEmpty)
        #expect(!FormatUtils.fileSize(1_000_000_000).isEmpty)
    }
}
