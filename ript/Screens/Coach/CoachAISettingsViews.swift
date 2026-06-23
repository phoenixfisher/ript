import SwiftUI

struct CoachAISettingsCard: View {
    @AppStorage("coachAIEnabled") private var isAIEnabled: Bool = false
    @AppStorage("coachAIModel") private var model: String = CoachAIResponseMode.balanced.model
    @State private var hasSavedKey: Bool = CoachAIKeychain.hasAPIKey
    @State private var showConnectionSheet: Bool = false

    var body: some View {
        Button {
            showConnectionSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(width: 30, height: 30)
                
                Text("AI Coach")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.primary)
            }
            .padding()
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI Coach Settings")
        .sheet(isPresented: $showConnectionSheet, onDismiss: refreshConnectionState) {
            NavigationStack {
                CoachAIConnectionSheet(
                    isAIEnabled: $isAIEnabled,
                    model: $model,
                    hasSavedKey: $hasSavedKey
                )
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            refreshConnectionState()
            normalizeModel()
        }
    }

    private func refreshConnectionState() {
        hasSavedKey = CoachAIKeychain.hasAPIKey
        if hasSavedKey == false {
            isAIEnabled = false
        }
    }

    private func normalizeModel() {
        if CoachAIResponseMode.isSupportedModel(model) == false {
            model = CoachAIResponseMode.balanced.model
        }
    }
}

struct CoachAIConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isAIEnabled: Bool
    @Binding var model: String
    @Binding var hasSavedKey: Bool
    @AppStorage("coachSuggestedMessagesEnabled") private var suggestedMessagesEnabled: Bool = true
    @State private var apiKey: String = ""
    @State private var isConnectionExpanded: Bool = false
    @State private var showConnectionAlert: Bool = false
    @State private var connectionAlertTitle: String = ""
    @State private var connectionAlertMessage: String = ""
    private let savedKeyPlaceholder = "saved-openai-key"

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedMode: CoachAIResponseMode {
        CoachAIResponseMode.mode(for: model)
    }

    private var connectionStatus: String {
        hasSavedKey ? "Saved" : "Missing"
    }

    private var shouldClearConnection: Bool {
        hasSavedKey && (trimmedAPIKey.isEmpty || trimmedAPIKey == savedKeyPlaceholder)
    }

    private var connectionActionTitle: String {
        shouldClearConnection ? "Clear" : "Save"
    }

    private var isConnectionActionDisabled: Bool {
        shouldClearConnection == false && (trimmedAPIKey.isEmpty || trimmedAPIKey == savedKeyPlaceholder)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button {
                    toggleAICoach()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("AI-Powered Responses", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Toggle("", isOn: $isAIEnabled)
                                .labelsHidden()
                                .disabled(hasSavedKey == false)
                                .allowsHitTesting(false)
                        }

                        if hasSavedKey == false {
                            Text("Add a key to turn AI Coach on.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    suggestedMessagesEnabled.toggle()
                    Haptics.light()
                } label: {
                    HStack {
                        Label("Suggested Messages", systemImage: "text.bubble.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Toggle("", isOn: $suggestedMessagesEnabled)
                            .labelsHidden()
                            .allowsHitTesting(false)
                    }
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    DisclosureGroup(isExpanded: $isConnectionExpanded) {
                        HStack(spacing: 8) {
                            SecureField("OpenAI API key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .onSubmit { Keyboard.dismiss() }
                                .textFieldStyle(.roundedBorder)

                            Button {
                                performConnectionAction()
                            } label: {
                                Text(connectionActionTitle)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 48)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .tint(shouldClearConnection ? .red : .green)
                            .disabled(isConnectionActionDisabled)
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            Label("OpenAI Connection", systemImage: "lock.shield.fill")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(connectionStatus)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(hasSavedKey ? .green : .secondary)
                        }
                    }
                    .tint(.primary)
                }
                .padding()
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                HStack {
                    Label("Response Mode", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Menu {
                        ForEach(CoachAIResponseMode.allCases) { mode in
                            Button {
                                model = mode.model
                            } label: {
                                if mode.model == model {
                                    Label(mode.title, systemImage: "checkmark")
                                } else {
                                    Text(mode.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedMode.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                }
                .padding()
                .frame(minHeight: 58)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") {
                dismiss()
            }
        }
        .alert(connectionAlertTitle, isPresented: $showConnectionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionAlertMessage)
        }
        .onAppear {
            normalizeModel()
            prepareAPIKeyField()
            isConnectionExpanded = hasSavedKey == false
        }
    }

    private func toggleAICoach() {
        guard hasSavedKey else {
            isConnectionExpanded = true
            return
        }

        isAIEnabled.toggle()
        Haptics.light()
    }

    private func saveConnection() {
        guard isConnectionActionDisabled == false else { return }

        CoachAIKeychain.saveAPIKey(trimmedAPIKey)
        hasSavedKey = CoachAIKeychain.hasAPIKey

        if hasSavedKey {
            isAIEnabled = true
            apiKey = savedKeyPlaceholder
            Haptics.success()
            showConnectionConfirmation(
                title: "OpenAI Key Saved",
                message: "AI Coach can use OpenAI when the switch is on."
            )
        }
    }

    private func clearConnection() {
        CoachAIKeychain.deleteAPIKey()
        hasSavedKey = false
        isAIEnabled = false
        apiKey = ""
        Haptics.success()
        showConnectionConfirmation(
            title: "OpenAI Key Cleared",
            message: "AI Coach will use local responses until a new key is saved."
        )
    }

    private func performConnectionAction() {
        if shouldClearConnection {
            clearConnection()
        } else {
            saveConnection()
        }
    }

    private func normalizeModel() {
        if CoachAIResponseMode.isSupportedModel(model) == false {
            model = CoachAIResponseMode.balanced.model
        }
    }

    private func prepareAPIKeyField() {
        if hasSavedKey && apiKey.isEmpty {
            apiKey = savedKeyPlaceholder
        }
    }

    private func showConnectionConfirmation(title: String, message: String) {
        connectionAlertTitle = title
        connectionAlertMessage = message
        showConnectionAlert = true
    }
}
