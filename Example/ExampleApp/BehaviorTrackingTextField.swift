import UIKit
import SynheartBehavior

/// Text field that emits clipboard behavior events when the user copies, pastes, or cuts.
/// Drop into any view; assign `behavior` and the field will forward clipboard activity to
/// the SDK via `BehaviorEvent.clipboard(...)` and `sendEvent(_:)`.
final class BehaviorTrackingTextField: UITextField {

    weak var behavior: SynheartBehavior?

    override func copy(_ sender: Any?) {
        super.copy(sender)
        emit(action: "copy")
    }

    override func paste(_ sender: Any?) {
        super.paste(sender)
        emit(action: "paste")
    }

    override func cut(_ sender: Any?) {
        super.cut(sender)
        emit(action: "cut")
    }

    private func emit(action: String) {
        guard let behavior, let sessionId = behavior.getCurrentSessionId() else { return }
        behavior.sendEvent(
            .clipboard(sessionId: sessionId, action: action, context: "text_input")
        )
    }
}
