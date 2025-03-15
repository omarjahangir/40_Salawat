import SwiftUI
import UserNotifications

// MARK: - Model & JSON Loader

struct SalawatItem: Codable, Identifiable {
    let id: Int        // Matches the "index" in your JSON.
    let Arabic: String
    let translation: String
}

func loadSalawat() -> [SalawatItem] {
    guard let url = Bundle.main.url(forResource: "salawat_v3", withExtension: "json") else {
        fatalError("Missing salawat.json in bundle.")
    }
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let items = try decoder.decode([SalawatItem].self, from: data)
        return items.sorted { $0.id < $1.id }
    } catch {
        fatalError("Error loading salawat.json: \(error)")
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    // This method ensures notifications are displayed as banners with sound even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - some functions
// Updated to accept a fontSize parameter.
func formatArabicText(_ text: String, fontSize: CGFloat) -> Text {
    let specialPhrases = [
        "الْمَحْمُوْدۨ"
        ,
        "مُحَمَّدٍۨ"
    ]
    
    var formattedText = Text("") // Start with an empty Text object
    let words = text.components(separatedBy: " ") // Split text by spaces

    for (index, word) in words.enumerated() {
        let wordText: Text
        if specialPhrases.contains(word) {
            wordText = Text(word)
                .font(.custom("KFGQPC HAFS Uthmanic Script", size: fontSize))
        } else {
            wordText = Text(word)
                .font(.custom("KFGQPCUthmanTahaNaskh", size: fontSize))
        }
        
        // Append with a space (except for the first word)
        formattedText = index == 0 ? wordText : formattedText + Text(" ") + wordText
    }
    
    return formattedText
}

// MARK: - ContentView

struct ContentView: View {
    @State private var fontSize: CGFloat = 30      // Default font size for most items
    @State private var salawat: [SalawatItem] = loadSalawat()
    @State private var showSettings = false
    @State private var showDuroodInfo = false
    @State private var showDeveloperInfo = false
    @StateObject private var notificationDelegate = NotificationDelegate()  // For handling notifications
    @AppStorage("showTranslation") private var showTranslation: Bool = true   // Persist translation display setting

    var body: some View {
        NavigationView {
            VStack {
                // Header with title and three buttons.
                HStack {
                    Text("40 Salawat")
                        .font(.largeTitle)
                        .bold()
                    
                    Spacer()
                    
                    // Inner HStack for the buttons with extra spacing.
                    HStack(spacing: 20) {
                        // Developer Info (i) button.
                        Button(action: { showDeveloperInfo.toggle() }) {
                            Image(systemName: "info.circle")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                        }
                        // Durood Info (book) button.
                        Button(action: { showDuroodInfo.toggle() }) {
                            Image(systemName: "book")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                        }
                        // Settings (gear) button.
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                
                // Main content scroll view.
                ScrollView {
                    VStack(alignment: .center, spacing: 40) {
                        ForEach(salawat) { item in
                            VStack(spacing: 10) {
                                if item.id == 0 {
                                    // The first salawat uses a fixed larger font.
                                    formatArabicText(item.Arabic, fontSize: 40)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                } else if item.id == 1 {
                                    // For id == 1, display Arabic text with slider-adjusted font size.
                                    formatArabicText(item.Arabic, fontSize: fontSize)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                } else {
                                    VStack(spacing: 4) {
                                        Text("\(item.id - 1)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        formatArabicText(item.Arabic, fontSize: fontSize)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                }

                                if showTranslation {
                                    Text(item.translation)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal) // Added horizontal padding
                                }
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            // Present sheets for settings, Durood info, and developer info.
            .sheet(isPresented: $showSettings) {
                SettingsView(fontSize: $fontSize)
            }
            .sheet(isPresented: $showDuroodInfo) {
                DuroodInfoView()
            }
            .sheet(isPresented: $showDeveloperInfo) {
                DeveloperInfoView()
            }
            .onAppear {
                // Set our notification delegate so banners are shown even in the foreground.
                UNUserNotificationCenter.current().delegate = notificationDelegate
            }
        }
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @Binding var fontSize: CGFloat
    @State private var selectedFontIndex: Int = 1 // Default is "Medium" (30pt)
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("showTranslation") private var showTranslation: Bool = true   // Persist translation display setting

    let fontSizes: [Int] = [20, 30, 40, 50]
    let labels: [String] = ["Small", "Medium", "Large", "Largest"]

    var body: some View {
        NavigationView {
            VStack {
                Text("Adjust Font Size")
                    .font(.headline)
                    .padding()
                
                // Discrete slider with values from 0.0 to 3.0.
                Slider(
                    value: Binding(
                        get: { Double(selectedFontIndex) },
                        set: { newValue in
                            selectedFontIndex = Int(newValue)
                            fontSize = CGFloat(fontSizes[selectedFontIndex])
                        }
                    ),
                    in: 0.0...3.0,
                    step: 1.0
                )
                .padding(.horizontal)
                
                // Simulated notches with labels below the slider.
                HStack {
                    ForEach(labels.indices, id: \.self) { index in
                        Text(labels[index])
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // Notifications toggle.
                Toggle(isOn: $notificationsEnabled) {
                    Text("Enable Notifications")
                }
                .padding()
                .onChange(of: notificationsEnabled) { newValue, _ in
                    if newValue {
                        requestNotificationPermission()
                        scheduleTestNotification()    // Test notification after 5 seconds.
                        scheduleRandomNotification()  // Random notification later in the day.
                    } else {
                        cancelNotifications()
                    }
                }
                
                // Toggle to show or hide translation.
                Toggle(isOn: $showTranslation) {
                    Text("Show Translation")
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                // Dismiss the settings view.
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.dismiss(animated: true, completion: nil)
                }
            })
        }
        .onAppear {
            // Sync slider with the current font size; default to Medium if not found.
            if let index = fontSizes.firstIndex(of: Int(fontSize)) {
                selectedFontIndex = index
            } else {
                selectedFontIndex = 1
                fontSize = CGFloat(fontSizes[selectedFontIndex])
            }
        }
    }
    
    // Request user permission for notifications.
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }
    
    // Schedule a test notification to fire 5 seconds after enabling.
    func scheduleTestNotification() {
        let messages = ["ﷺ", "صلى الله عليه وسلم"]
        let randomMessage = messages.randomElement() ?? "ﷺ"
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = randomMessage
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "salawatTestNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling test notification: \(error)")
            }
        }
    }
    
    // Schedule a random notification at a random time later in the day.
    func scheduleRandomNotification() {
        let messages = ["ﷺ", "صلى الله عليه وسلم"]
        let randomMessage = messages.randomElement() ?? "ﷺ"
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Reminder"
        content.body = randomMessage
        content.sound = .default
        
        // Generate a random time between 9 AM and 9 PM.
        var dateComponents = DateComponents()
        dateComponents.hour = Int.random(in: 9...21)
        dateComponents.minute = Int.random(in: 0...59)
        
        // Use a calendar trigger that repeats daily.
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "salawatDailyNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily notification: \(error)")
            }
        }
    }

    
    // Cancel any scheduled notifications.
    func cancelNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "salawatTestNotification",
            "salawatRandomNotification"
        ])
    }
}

// MARK: - DuroodInfoView

struct DuroodInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Importance of Salawat and Durood")
                        .font(.largeTitle)
                        .bold()
                    Text("إِنَّ ٱللَّهَ وَمَلَـٰٓئِكَتَهُۥ يُصَلُّونَ عَلَى ٱلنَّبِىِّ ۚ يَـٰٓأَيُّهَا ٱلَّذِينَ ءَامَنُوا صَلُّوا عَلَيْهِ وَسَلِّمُوا تَسْلِيمًا ").font(.custom("KFGQPC HAFS Uthmanic Script", size: 30))
                        .multilineTextAlignment(.center)
                    Text("Indeed, Allāh confers blessing upon the Prophet, and His angels [ask Him to do so]. O you who have believed, ask [Allāh to confer] blessing upon him and ask [Allāh to grant him] peace.").italic()
                    Divider()
                    Text("""
                    Durood is an invocation of blessings upon the Prophet Muhammad ﷺ. It is highly emphasized in the Quran and Hadith as a means to show respect and receive spiritual rewards. Reciting Durood is believed to bring mercy, protection, and blessings to the reciter, with the Prophet ﷺ having narrated:
                    """)
                    Text("Whoever sends blessings upon me once, Allah ﷻ will send blessings upon him ten times.").italic()
                }
                .padding()
            }
            .navigationBarTitle("Durood Info", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - DeveloperInfoView

struct DeveloperInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var bookImage: UIImage? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // About the Developer section
                    Text("About the App")
                        .font(.largeTitle)
                        .bold()
                    Text("""
                    The 40 Salawat app is designed to help users engage with sending salutations to the Prophet ﷺ while providing useful settings and additional information about the importance of Durood. Your feedback is welcome!
                    """)
                        .font(.body)
                    
                    Divider()
                    
                    // Other Works section
                    Text("Other Works")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("25 Questions You've Always Wanted To Ask Your Muslim Co-Worker")
                        .font(.headline)
                        .padding(.top, 5)
                    
                    Group {
                        Image("book_cover2")
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    
                    Text("""
                    Looking for the perfect gift for your non-Muslim co-worker? **25 Questions You've Always Wanted To Ask Your Muslim Co-Worker** is a thoughtful and engaging book that answers common questions about Islam in a clear, friendly, and approachable way. It’s designed to foster understanding and meaningful conversations in the workplace and beyond. **Give it as a gift** to help break down misconceptions and build bridges. Available now on **Amazon** and at **select local bookstores**.
                    """)
                        .font(.body)
                    
                    Divider()
                    
                    // Other Apps section
                    Text("Other Apps")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ForEach(["Hans Wehr",
                             "Lanes Lexicon",
                             "Lisan al Arab",
                             "Penrice",
                             "Steingass",
                             "Qamus Alfaz"
                            ], id: \.self) { work in
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundColor(.blue)
                            Text(work)
                                .font(.body)
                        }
                        .padding(.vertical, 3)
                    }
                    
                    Divider()
                }
                .padding()
            }
            .navigationBarTitle("Developer Info", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

