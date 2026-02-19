import UIKit
import SynheartBehavior

/// Text field that notifies the Synheart Behavior SDK when the user copies, pastes, or cuts
/// so clipboard_activity_rate can be computed. Use this (or wire recordCopy/recordPaste/recordCut
/// in your own text view) to get non-zero copy/paste/cut counts.
final class BehaviorTrackingTextField: UITextField {

    weak var behavior: SynheartBehavior?

    override func copy(_ sender: Any?) {
        super.copy(sender)
        behavior?.recordCopy()
    }

    override func paste(_ sender: Any?) {
        super.paste(sender)
        behavior?.recordPaste()
    }

    override func cut(_ sender: Any?) {
        super.cut(sender)
        behavior?.recordCut()
    }
}
