import AuthenticationServices
import UIKit

/// Opens the WHOOP sign-in in a system browser sheet. Tokens never reach the phone:
/// the Supabase function stores them and redirects back to achillesrecovery://whoop/connected.
@MainActor
final class WhoopConnector: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func connect() async -> Bool {
        guard let url = URL(string: Secrets.supabaseURL + "/functions/v1/whoop-auth/start") else { return false }
        return await withCheckedContinuation { continuation in
            let s = ASWebAuthenticationSession(url: url, callbackURLScheme: "achillesrecovery") { callback, _ in
                continuation.resume(returning: callback?.host == "whoop" && callback?.path == "/connected")
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            session = s
            if !s.start() { continuation.resume(returning: false) }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
