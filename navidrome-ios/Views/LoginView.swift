import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var canSignIn: Bool {
        !isLoading
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "hifispeaker.2")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Music Sync")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Connect to your server")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Form fields
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("http://192.168.1.16:4533", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Username")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 24)

            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Login button
            Button(action: login) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isLoading ? Color.gray.opacity(0.3) : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isLoading)
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    private func login() {
        errorMessage = nil

        guard !serverURL.isEmpty else {
            errorMessage = "Please enter a server URL."
            return
        }
        guard !username.isEmpty else {
            errorMessage = "Please enter a username."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter a password."
            return
        }

        isLoading = true

        // Normalize the URL
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://\(url)"
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }

        let trimmedUser = username.trimmingCharacters(in: .whitespaces)
        let trimmedPass = password

        Task {
            do {
                try await NavidromeClient.shared.validateCredentials(
                    serverURL: url,
                    username: trimmedUser,
                    password: trimmedPass
                )

                AppConfig.serverURL = url
                AppConfig.username = trimmedUser
                AppConfig.password = trimmedPass

                isLoggedIn = true
            } catch NavidromeError.authFailed {
                errorMessage = "Invalid username or password."
            } catch NavidromeError.invalidURL {
                errorMessage = "Invalid server URL."
            } catch {
                errorMessage = "Could not connect to server.\n\(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
