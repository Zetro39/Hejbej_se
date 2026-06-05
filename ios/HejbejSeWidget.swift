import WidgetKit
import SwiftUI

private struct WidgetData: Decodable {
    let totalDistance: Double
    let streak: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), totalDistance: 0.0, streak: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), totalDistance: 1.2, streak: 5)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Read data shared from Flutter via App Groups / SharedPreferences
        // iOS requires configuring App Groups in Xcode (e.g. group.com.example.hejbejSe)
        let sharedDefaults = UserDefaults(suiteName: "group.com.zetro39.hejbejse")
        
        let totalDistance = sharedDefaults?.double(forKey: "totalDistance") ?? 0.0
        let streak = sharedDefaults?.integer(forKey: "streak") ?? 0
        
        let entry = SimpleEntry(date: Date(), totalDistance: totalDistance, streak: streak)
        
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let totalDistance: Double
    let streak: Int
}

struct HejbejSeWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hejbej se!")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            Text(String(format: "Dnes: %.1f km", entry.totalDistance))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            Text("Série: 🔥 \(entry.streak) dnů")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.93, green: 1.0, blue: 0.25), Color(red: 0.95, green: 1.0, blue: 0.5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

@main
struct HejbejSeWidget: Widget {
    let kind: String = "HejbejSeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HejbejSeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hejbej se Widget")
        .description("Sleduj své kilometry a denní sérii přímo na ploše.")
        .supportedFamilies([.systemSmall])
    }
}
