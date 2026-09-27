import XCTest
@testable import FitnessApp

final class UnitsTests: XCTestCase {
    func testWeightFollowsTheUnitSystemByDefault() {
        XCTAssertEqual(Units(system: .metric).weightUnit, "kg")
        XCTAssertEqual(Units(system: .imperial).weightUnit, "lb")
        XCTAssertEqual(Units(system: .metric, weight: .st).weightUnit, "st")
    }

    func testStones() {
        let st = Units(system: .metric, weight: .st)
        // 80 kg = 176.37 lb = 12 st 8.4 lb
        XCTAssertEqual(st.weightString(kg: 80), "12 st 8.4 lb")
        XCTAssertEqual(st.weightValue(kg: 80), 12.598, accuracy: 0.001)
        XCTAssertEqual(st.kg(fromDisplayWeight: st.weightValue(kg: 80)), 80, accuracy: 0.0001)
        // Changes under a stone read in pounds.
        XCTAssertEqual(st.weightString(kg: -1.5, signed: true), "-3.3 lb")
        XCTAssertEqual(st.weightString(kg: 7, signed: true), "+1 st 1.4 lb")
    }

    func testStonesNeverShowFourteenPounds() {
        let st = Units(system: .metric, weight: .st)
        // 13.99 st would round to "13 st 14.0 lb"; it should carry to 14 st.
        let kg = 13.999 * 14 / Units.lbPerKg
        XCTAssertEqual(st.weightString(kg: kg), "14 st 0.0 lb")
    }

    func testKilojoules() {
        XCTAssertEqual(EnergyUnit.kcal.string(kcal: 500), "500 kcal")
        XCTAssertEqual(EnergyUnit.kJ.string(kcal: 500), "2092 kJ")
        XCTAssertEqual(EnergyUnit.kJ.value(kcal: 100), 418.4, accuracy: 0.001)
    }
}
