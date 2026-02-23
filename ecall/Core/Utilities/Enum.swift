import SwiftUI

enum ColorType: String {
    case A = "A"
    case B = "B"
    case C = "C"
    case D = "D"
    case E = "E"
    case F = "F"
    case G = "G"
    case H = "H"
    case I = "I"
    case J = "J"
    case K = "K"
    case L = "L"
    case M = "M"
    case N = "N"
    case O = "O"
    case P = "P"
    case Q = "Q"
    case R = "R"
    case S = "S"
    case T = "T"
    case U = "U"
    case V = "V"
    case W = "W"
    case X = "X"
    case Y = "Y"
    case Z = "Z"

    case n0 = "0"
    case n1 = "1"
    case n2 = "2"
    case n3 = "3"
    case n4 = "4"
    case n5 = "5"
    case n6 = "6"
    case n7 = "7"
    case n8 = "8"
    case n9 = "9"

    init(fromRawValue: String) {
        self = ColorType.init(rawValue: fromRawValue.uppercased()) ?? .n0
    }

    var color: Color {
        return hexColorString.hexColor
    }

    var hexColorString: String {
        var result = ColorType.n0.rawValue

        switch self {
        case .A:
            result = "#003B70"
        case .B:
            result = "#2D9CFF"
        case .C:
            result = "#F7534F"
        case .D:
            result = "#F9C441"
        case .E:
            result = "#6496ED"
        case .F:
            result = "#00A79D"
        case .G:
            result = "#0093AE"
        case .H:
            result = "#F21914"
        case .I:
            result = "#FFA9A9"
        case .J:
            result = "#67C1E4"
        case .K:
            result = "#9FCC48"
        case .L:
            result = "#F37365"
        case .M:
            result = "#0071B8"
        case .N:
            result = "#005ECE"
        case .O:
            result = "#7ADDDD"
        case .P:
            result = "#FFAB54"
        case .Q:
            result = "#49EBA0"
        case .R:
            result = "#52CB14"
        case .S:
            result = "#847DFF"
        case .T:
            result = "#4D3FF4"
        case .U:
            result = "#79AE12"
        case .V:
            result = "#237A75"
        case .W:
            result = "#0091C9"
        case .X:
            result = "#A721B6"
        case .Y:
            result = "#FC61D4"
        case .Z:
            result = "#CB215A"
        case .n0:
            result = "#619CFC"
        case .n1:
            result = "#3A5CF8"
        case .n2:
            result = "#7BCEC9"
        case .n3:
            result = "#CB2182"
        case .n4:
            result = "#703AFF"
        case .n5:
            result = "#2135CB"
        case .n6:
            result = "#00D6BE"
        case .n7:
            result = "#CBA421"
        case .n8:
            result = "#E8CA63"
        case .n9:
            result = "#990000"
        }

        return result
    }
}

// MARK: - Call Status (Room-level)
enum CallStatus: String, Codable, RawValueInitializable {
    case requesting     // Initiating call
    case ringing        // Receiving incoming call
    case connecting     // WebRTC connecting
    case connected      // Call is active
    case ended          // Call ended - defaultCase

    static var defaultCase: CallStatus { .ended }

    var title: String {
        switch self {
        case .requesting:   return KeyLocalized.requesting
        case .ringing:      return KeyLocalized.ringing
        case .connecting:   return KeyLocalized.connecting_call
        case .connected:    return ""
        case .ended:        return KeyLocalized.ended
        }
    }
}

// MARK: - Participant Status (Individual participant state)
enum ParticipantStatus: String, Codable, RawValueInitializable {
    case inviting       // Invitation sent, waiting for response
    case accepted       // Accepted, joining the call
    case rejected       // Rejected the invitation
    case reconnecting   // Reconnecting after network issue
    case connected      // Connected to the call
    case left           // Left the call

    static var defaultCase: ParticipantStatus { .left }

    var title: String {
        switch self {
        case .inviting:  return KeyLocalized.inviting
        case .accepted:  return KeyLocalized.connecting_call  // Reuse existing key
        case .rejected:  return KeyLocalized.rejected
        case .connected: return ""
        case .reconnecting: return KeyLocalized.reconnecting
        case .left:      return KeyLocalized.ended  // Reuse existing key
        }
    }
}
