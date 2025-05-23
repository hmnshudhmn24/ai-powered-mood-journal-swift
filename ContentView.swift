// AI-Powered Mood Journal in Swift
// Technologies: Swift, CoreML, NLPKit (or Apple's Natural Language), Charts, CloudKit
// This project assumes Xcode setup with SwiftUI lifecycle

import SwiftUI
import NaturalLanguage
import Charts
import CloudKit

struct JournalEntry: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
    let moodScore: Double // from -1 (sad) to 1 (happy)
}

class JournalViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var inputText: String = ""

    private let container = CKContainer.default()

    func analyzeMood(from text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0.0
    }

    func addEntry() {
        let score = analyzeMood(from: inputText)
        let newEntry = JournalEntry(date: Date(), text: inputText, moodScore: score)
        entries.insert(newEntry, at: 0)
        inputText = ""
        saveToCloud(entry: newEntry)
    }

    func saveToCloud(entry: JournalEntry) {
        let record = CKRecord(recordType: "JournalEntry")
        record["date"] = entry.date as CKRecordValue
        record["text"] = entry.text as CKRecordValue
        record["moodScore"] = entry.moodScore as CKRecordValue

        container.privateCloudDatabase.save(record) { _, error in
            if let error = error {
                print("CloudKit error: \(error.localizedDescription)")
            }
        }
    }

    func fetchFromCloud() {
        let query = CKQuery(recordType: "JournalEntry", predicate: NSPredicate(value: true))
        container.privateCloudDatabase.perform(query, inZoneWith: nil) { results, error in
            if let records = results {
                DispatchQueue.main.async {
                    self.entries = records.map { record in
                        JournalEntry(
                            date: record["date"] as? Date ?? Date(),
                            text: record["text"] as? String ?? "",
                            moodScore: record["moodScore"] as? Double ?? 0.0
                        )
                    }.sorted(by: { $0.date > $1.date })
                }
            } else if let error = error {
                print("Fetch error: \(error.localizedDescription)")
            }
        }
    }
}

struct MoodChartView: View {
    var entries: [JournalEntry]

    var body: some View {
        Chart(entries) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value("Mood", entry.moodScore)
            )
            .foregroundStyle(by: .value("Mood", entry.moodScore >= 0 ? "Positive" : "Negative"))
        }
        .frame(height: 300)
        .padding()
    }
}

struct ContentView: View {
    @StateObject private var viewModel = JournalViewModel()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("How are you feeling today?")
                    .font(.title2)
                TextEditor(text: $viewModel.inputText)
                    .frame(height: 150)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))

                Button("Analyze and Save") {
                    viewModel.addEntry()
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical)

                MoodChartView(entries: viewModel.entries)

                List(viewModel.entries) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(entry.text)
                        Text(String(format: "Mood Score: %.2f", entry.moodScore))
                            .font(.caption)
                            .foregroundColor(entry.moodScore >= 0 ? .green : .red)
                    }
                }
            }
            .padding()
            .navigationTitle("Mood Journal")
            .onAppear {
                viewModel.fetchFromCloud()
            }
        }
    }
}

@main
struct MoodJournalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
