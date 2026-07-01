import SwiftUI
import UIKit

struct KeyboardView: View {
    @ObservedObject var networkService: NetworkService
    @State private var shifted = false
    @State private var symbols = false

    private let letters: [[String]] = [["Q","W","E","R","T","Y","U","I","O","P"],["A","S","D","F","G","H","J","K","L"],["Z","X","C","V","B","N","M"]]
    private let syms: [[String]] = [["1","2","3","4","5","6","7","8","9","0"],["-","/",":",";","(",")","$","&","@","\""],[".",",","?","!","'","`","~","%","^","*"]]

    var body: some View {
        VStack(spacing: 4) {
            if symbols { symGrid } else { letterGrid }
            HStack(spacing: 4) {
                mk("Del") { tap("backspace") }.frame(width: 58); mk("Tab") { tap("tab") }.frame(width: 46)
                Spacer()
                Button(action: { tap(" ") }) { Text("Space").font(.caption).frame(maxWidth: .infinity).frame(height: 36).background(Color.gray.opacity(0.2)).cornerRadius(7) }
                Spacer()
                mk("Ret") { tap("return") }.frame(width: 54)
            }
            HStack(spacing: 4) {
                mk(symbols ? "ABC" : "123") { symbols.toggle() }.frame(width: 42)
                mk(shifted ? "↑" : "↓") { shifted.toggle(); tap("shift") }.frame(width: 34)
                Spacer()
                mk("Hide") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.frame(width: 46)
                mk("Ctrl") { tap("ctrl") }.frame(width: 38); mk("Alt") { tap("alt") }.frame(width: 34); mk("⎈⎇⌘") { tap("ctrl"); tap("alt"); tap("cmd") }.frame(width: 42)
            }
        }.padding(.horizontal, 4).padding(.vertical, 6).background(.ultraThinMaterial)
    }

    private var letterGrid: some View {
        VStack(spacing: 4) {
            ForEach(letters, id: \.self) { r in
                HStack(spacing: 4) {
                    if r == letters[1] { Color.clear.frame(width: 12) }; if r == letters[2] { Color.clear.frame(width: 28) }
                    ForEach(r, id: \.self) { k in key(shifted ? k.lowercased() : k) }
                    if r == letters[1] { Color.clear.frame(width: 12) }; if r == letters[2] { Color.clear.frame(width: 28) }
                }
            }
        }
    }

    private var symGrid: some View {
        VStack(spacing: 4) {
            ForEach(syms, id: \.self) { r in HStack(spacing: 4) { ForEach(r, id: \.self) { k in key(k) } } }
        }
    }

    private func key(_ l: String) -> some View {
        Button(action: { tap(l) }) { Text(l).font(.system(size: 15)).frame(maxWidth: .infinity).frame(height: 36).background(Color.gray.opacity(0.12)).cornerRadius(7) }.buttonStyle(.plain)
    }

    private func mk(_ l: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Text(l).font(.system(size: 10, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 36).background(Color.gray.opacity(0.18)).cornerRadius(7) }.buttonStyle(.plain)
    }

    private func tap(_ k: String) { networkService.sendTap(k); if shifted && k.count == 1 { shifted = false } }
}
