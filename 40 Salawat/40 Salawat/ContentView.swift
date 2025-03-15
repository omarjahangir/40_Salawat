import SwiftUI
import UserNotifications
import StoreKit


// MARK: - Model & JSON Loader

struct SalawatItem: Codable, Identifiable {
    let id: Int        // Matches the "index" in your JSON.
    let Arabic: String
    let translation: String
}

func loadSalawat() -> [SalawatItem] {
    guard let url = Bundle.main.url(forResource: "salawat_v4", withExtension: "json") else {
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



// Add to your SalawatItem struct or somewhere in your model code
class AppSettings: ObservableObject {
    @Published var appLaunchCount: Int {
        didSet {
            UserDefaults.standard.set(appLaunchCount, forKey: "appLaunchCount")
        }
    }
    @Published var lastReviewRequestDate: Date? {
        didSet {
            if let date = lastReviewRequestDate {
                UserDefaults.standard.set(date, forKey: "lastReviewRequestDate")
            }
        }
    }
    @Published var hasGivenReview: Bool {
        didSet {
            UserDefaults.standard.set(hasGivenReview, forKey: "hasGivenReview")
        }
    }
    
    init() {
        self.appLaunchCount = UserDefaults.standard.integer(forKey: "appLaunchCount")
        self.hasGivenReview = UserDefaults.standard.bool(forKey: "hasGivenReview")
        
        if let savedDate = UserDefaults.standard.object(forKey: "lastReviewRequestDate") as? Date {
            self.lastReviewRequestDate = savedDate
        } else {
            self.lastReviewRequestDate = nil
        }
    }
    
    func incrementLaunchCount() {
        appLaunchCount += 1
    }
    
    func shouldShowReviewPrompt() -> Bool {
        // Don't show if user has already reviewed
        if hasGivenReview {
            return false //should be false
        }
        
        // Show review prompt after 5 launches
        if appLaunchCount >= 3 {
            // If we've never shown the prompt, show it
            if lastReviewRequestDate == nil {
                return true
            }
            
            // Otherwise, only show once every 30 days
            if let lastDate = lastReviewRequestDate {
                let calendar = Calendar.current
                if let difference = calendar.dateComponents([.day], from: lastDate, to: Date()).day,
                   difference >= 30 {
                    return true
                }
            }
        }
        
        return false
    }
}

// Review Prompt View
struct ReviewPromptView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.yellow)
                .padding(.top, 20)
            
            Text("Enjoying 40 Salawat?")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your feedback helps us improve and reach more Muslims who can benefit from sending Salawat upon the Prophet ﷺ.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: {
                    // User declined
                    isPresented = false
                }) {
                    Text("Not Now")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // Mark that user has reviewed
                    appSettings.hasGivenReview = true
                    appSettings.lastReviewRequestDate = Date()
                    
                    // Open App Store page instead of using the review controller
                    if let writeReviewURL = URL(string: "https://apps.apple.com/app/id6743085313?action=write-review") {
                        UIApplication.shared.open(writeReviewURL, options: [:], completionHandler: nil)
                    }
                    
                    isPresented = false
                }) {
                    Text("Rate the App")
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding(.bottom, 20)
        }
        .frame(width: 300)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
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
        "مُحَمَّدٍۨ"
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



// Modified ContentView to include review prompt
struct ContentView: View {
    @State private var fontSize: CGFloat = 30
    @State private var salawat: [SalawatItem] = loadSalawat()
    @State private var showSettings = false
    @State private var showDuroodInfo = false
    @State private var showDeveloperInfo = false
    @State private var showReviewPrompt = false
    @StateObject private var notificationDelegate = NotificationDelegate()
    @StateObject private var appSettings = AppSettings()
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
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
                                    formatArabicText(item.Arabic, fontSize: 40)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                } else if item.id == 1 {
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
                                        .padding(.horizontal)
                                }
                            }
                            .frame(maxWidth: horizontalSizeClass == .regular ? 900 : .infinity)
                        }
                    }
                    .padding(.top)
                    .frame(maxWidth: .infinity)
                }
            }
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
                // Set notification delegate
                UNUserNotificationCenter.current().delegate = notificationDelegate
                
                // Increment app launch count
                appSettings.incrementLaunchCount()
                
                // Check if we should show the review prompt
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if appSettings.shouldShowReviewPrompt() {
                        showReviewPrompt = true
                        appSettings.lastReviewRequestDate = Date()
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .edgesIgnoringSafeArea(.bottom)
        .environmentObject(appSettings)
        .overlay {
            if showReviewPrompt {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showReviewPrompt = false
                        }
                    
                    ReviewPromptView(isPresented: $showReviewPrompt)
                        .environmentObject(appSettings)
                }
            }
        }
    }
}





// MARK: - SettingsView


struct SettingsView: View {
    @Binding var fontSize: CGFloat
    @State private var selectedFontIndex: Int = 1 // Default is "Medium" (30pt)
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false // Already false by default
    @AppStorage("showTranslation") private var showTranslation: Bool = true   // Persist translation display setting
    @Environment(\.presentationMode) var presentationMode

    let fontSizes: [Int] = [20, 30, 40, 50]
    let labels: [String] = ["Small", "Medium", "Large", "Largest"]

    var body: some View {
        NavigationStack {
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
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enable notifications to receive your daily reminder to recite Durood.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Toggle(isOn: $notificationsEnabled) {
                        Text("Enable Notifications")
                    }
                }
                .padding()
                .onChange(of: notificationsEnabled) { oldValue, newValue in
                    if newValue {
                        // User turned ON notifications
                        requestNotificationPermission()
                    } else {
                        // User turned OFF notifications
                        cancelNotifications()
                    }
                }
                
                Divider()
                // Toggle to show or hide translation.
                Toggle(isOn: $showTranslation) {
                    Text("Show Translation")
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            // Limit width for better iPad display
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            // Sync slider with the current font size; default to Medium if not found.
            if let index = fontSizes.firstIndex(of: Int(fontSize)) {
                selectedFontIndex = index
            } else {
                selectedFontIndex = 1
                fontSize = CGFloat(fontSizes[selectedFontIndex])
            }
            
            // Check current notification settings on appear
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    // Only update UI if there's a mismatch between stored state and actual permission
                    if settings.authorizationStatus != .authorized && notificationsEnabled {
                        notificationsEnabled = false
                    }
                }
            }
        }
    }
    
    // Request user permission for notifications.
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
                // If there was an error, revert the toggle on the main thread
                DispatchQueue.main.async {
                    self.notificationsEnabled = false
                }
            } else {
                print("Notification permission granted: \(granted)")
                // Only schedule notifications if permission was granted
                if granted {
                    DispatchQueue.main.async {
                        self.scheduleTestNotification()
                        self.scheduleRandomNotification()
                    }
                } else {
                    // If permission was denied, revert the toggle on the main thread
                    DispatchQueue.main.async {
                        self.notificationsEnabled = false
                    }
                }
            }
        }
    }
    
    // Schedule a test notification to fire 5 seconds after enabling.
    func scheduleTestNotification() {
        let messages = ["ﷺ", "صلى الله عليه وسلم"]
        let randomMessage = messages.randomElement() ?? "ﷺ"
        
        let content = UNMutableNotificationContent()
        content.title = "Durood Notification"
        content.body = "Time to send blessings upon the Prophet " + randomMessage
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
        let messages = ["ﷺ", "صلى الله عليه وسلم", "صلى الله عليه وآله وسلم"]
        let randomMessage = messages.randomElement() ?? "ﷺ"
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Durood Reminder"
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
            "salawatDailyNotification"  // Fixed identifier from "salawatRandomNotification"
        ])
    }
}



// MARK: - DuroodInfoView

struct DuroodInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Importance of Salawat and Durood")
                        .font(.largeTitle)
                        .bold()
                    Text("إِنَّ ٱللَّهَ وَمَلَـٰٓئِكَتَهُۥ يُصَلُّونَ عَلَى ٱلنَّبِىِّ ۚ يَـٰٓأَيُّهَا ٱلَّذِينَ ءَامَنُوا صَلُّوا عَلَيْهِ وَسَلِّمُوا تَسْلِيمًا ").font(.custom("KFGQPC HAFS Uthmanic Script", size: 30))
                        .multilineTextAlignment(.center)
                    Text("Indeed, Allāh confers blessing upon the Prophet, and His angels [ask Him to do so]. O you who have believed, ask [Allāh to confer] blessing upon him and ask [Allāh to grant him] peace.").italic()
                    Divider()
                    Text("""
                    Durood is an invocation of blessings upon the Prophet Muhammad ﷺ. It is highly emphasized in the Quran and Hadith as a means to show respect and receive spiritual rewards. Reciting Durood is believed to bring mercy, protection, and blessings to the reciter, with the Prophet ﷺ having narrated:
                    """)
                    Text("Whoever sends blessings upon me once, Allah ﷻ will send blessings upon him ten times.").italic()
                }
                .padding()
                // Use adaptive layout based on device size
                .frame(maxWidth: horizontalSizeClass == .regular ? 800 : nil)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var bookImage: UIImage? = nil

    var body: some View {
        NavigationStack {
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
                    .frame(height: 300) // Reduced height to something more reasonable
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    
                    Text("""
                    Looking for the perfect gift for your non-Muslim co-worker? **25 Questions You've Always Wanted To Ask Your Muslim Co-Worker** is a thoughtful and engaging book that answers common questions about Islam in a clear, friendly, and approachable way. It's designed to foster understanding and meaningful conversations in the workplace and beyond. **Give it as a gift** to help break down misconceptions and build bridges. Available now on **Amazon** and at **select local bookstores**.
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
                // Use adaptive layout based on device size
                .frame(maxWidth: horizontalSizeClass == .regular ? 800 : nil)
                
                Text("Please also remember this developer, his family and his teachers in your duas. May Allah ﷻ accept all of our efforts. Ameen! ")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
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
