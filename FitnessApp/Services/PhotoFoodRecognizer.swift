import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Suggests foods from a meal photo, all on device. Vision's image classifier names what it sees
/// ("pizza", "salad", "french fries"); on iOS 26 with Apple Intelligence, the on-device language
/// model turns those labels into likely foods with amounts. Each name is then matched to a saved
/// food the same way typed sentences are.
enum PhotoFoodRecognizer {
    struct Suggestion: Identifiable {
        let id = UUID()
        var food: FoodItem
        var servings: Double
        /// What the photo was read as, e.g. "french fries".
        var source: String
    }

    static func suggestions(for image: PlatformImage, foods: [FoodItem]) async -> [Suggestion] {
        let labels = await classify(image)
        var names = PhotoFoodSuggester.candidates(labels)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), !names.isEmpty, let described = await PlateDescriber.foods(from: names) {
            names = described + names
        }
        #endif
        return PhotoFoodSuggester.suggestions(for: names, foods: foods)
    }

    /// Vision's labels for the image with their confidence.
    static func classify(_ image: PlatformImage) async -> [(label: String, confidence: Float)] {
        guard let cgImage = image.cgImage else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }
            return (request.results ?? []).map { (label: $0.identifier, confidence: $0.confidence) }
        }.value
    }
}

/// The pure part of photo suggestions, kept apart so it can be tested without images.
enum PhotoFoodSuggester {
    static let minimumConfidence: Float = 0.15
    static let limit = 4

    /// Labels too general to be a food.
    private static let generic: Set<String> = [
        "food", "dish", "meal", "cuisine", "plate", "bowl", "tableware", "table", "dining table", "utensil",
        "fork", "knife", "spoon", "cup", "mug", "glass", "drink", "beverage", "produce", "ingredient",
        "baked goods", "dessert", "snack", "fast food", "comfort food", "vegetable", "fruit", "meat", "structure",
        "indoor", "outdoor", "wood", "cloth", "textile", "people", "adult", "hand",
    ]

    /// Confident, specific labels as plain names, most confident first ("french_fries" → "french fries").
    static func candidates(_ labels: [(label: String, confidence: Float)]) -> [String] {
        var seen = Set<String>()
        return labels
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }
            .map { $0.label.replacingOccurrences(of: "_", with: " ").lowercased() }
            .filter { !generic.contains($0) && seen.insert($0).inserted }
    }

    /// Each name ("2 eggs", "salad") matched to a saved food, one suggestion per food.
    static func suggestions(for names: [String], foods: [FoodItem], limit: Int = limit) -> [PhotoFoodRecognizer.Suggestion] {
        var result: [PhotoFoodRecognizer.Suggestion] = []
        for name in names {
            guard result.count < limit, let item = FoodSentenceParser.parseItem(name),
                  let food = FoodSentenceParser.bestMatch(item.name, in: foods, candidate: {
                      .init(name: $0.name, other: [$0.brand], isFavorite: $0.isFavorite, lastUsed: $0.lastUsed)
                  }),
                  !result.contains(where: { $0.food.uuid == food.uuid }) else { continue }
            let servings = FoodSentenceParser.servings(for: item, servingDescription: food.servingDescription,
                                                       presets: food.servingPresets)
            result.append(.init(food: food, servings: max(servings, 0.25), source: name))
        }
        return result
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct PlateGuess {
    @Guide(description: "The foods most likely on the plate, most prominent first, each as a short everyday name with a typical single-person amount, such as \"2 eggs\", \"1 cup rice\" or \"1 slice pizza\". At most five.")
    var foods: [String]
}

@available(iOS 26.0, macOS 26.0, *)
enum PlateDescriber {
    /// Likely foods with amounts for the image labels, or nil when the model isn't available.
    static func foods(from labels: [String]) async -> [String]? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: """
            You help people log meals in a calorie tracker. An image classifier has labelled a photo of a meal. \
            Suggest the foods most likely on the plate. Use only foods the labels support; don't invent extras.
            """)
        do {
            let response = try await session.respond(to: "Labels, most confident first: \(labels.joined(separator: ", ")).",
                                                     generating: PlateGuess.self)
            return Array(response.content.foods.prefix(5))
        } catch {
            return nil
        }
    }
}
#endif
