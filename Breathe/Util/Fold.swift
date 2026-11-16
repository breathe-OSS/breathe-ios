// SPDX-License-Identifier: MIT
/*
 * Fold.swift - iPhone Duo fold and reserved region helpers
 *
 * Copyright (C) 2026 The Breathe Open Source Project
 * Copyright (C) 2026 sidharthify <wednisegit@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */


import SwiftUI

struct FoldLayout: Equatable {
    var width: CGFloat = 0
    var division: CGRect? = nil

    var verticalDivision: CGRect? {
        guard let division, division.height > division.width else {
            return nil
        }
        guard division.minX > 0, division.maxX < width else {
            return nil
        }
        return division
    }

    func columns(_ count: Int, spacing: CGFloat) -> [GridItem] {
        guard let fold = verticalDivision, count % 2 == 0 else {
            return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
        }
        let half = count / 2
        let inner = spacing * CGFloat(half - 1)
        let leading = max((fold.minX - inner) / CGFloat(half), 0)
        let trailing = max((width - fold.maxX - inner) / CGFloat(half), 0)
        var items: [GridItem] = []
        for index in 0..<count {
            let size = index < half ? leading : trailing
            let gap = index == half - 1 ? fold.width : spacing
            items.append(GridItem(.fixed(size), spacing: gap))
        }
        return items
    }
}

private struct FoldReader: ViewModifier {
    @Binding var layout: FoldLayout

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let current = FoldLayout(width: proxy.size.width, division: division(in: proxy))
                Color.clear
                    .onAppear {
                        layout = current
                    }
                    .onChange(of: current) { _, value in
                        layout = value
                    }
            }
        }
    }

    private func division(in proxy: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).first?.frame
        }
        return nil
    }
}

private struct ReservedRegionInset: ViewModifier {
    let corner: Alignment
    let footprint: CGSize

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .padding(edgeInsets(in: proxy))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner)
        }
    }

    private func edgeInsets(in proxy: GeometryProxy) -> EdgeInsets {
        guard #available(iOS 27.1, *) else {
            return EdgeInsets()
        }
        let size = proxy.size
        let zone = CGRect(
            x: corner.horizontal == .trailing ? size.width - footprint.width : 0,
            y: corner.vertical == .bottom ? size.height - footprint.height : 0,
            width: footprint.width,
            height: footprint.height
        )
        let regions = proxy.reservedRegions(kind: .occlusion) + proxy.reservedRegions(kind: .division)
        var insets = EdgeInsets()
        for region in regions where region.frame.intersects(zone) {
            let frame = region.frame
            if frame.height > frame.width {
                if corner.horizontal == .trailing {
                    insets.trailing = max(insets.trailing, size.width - frame.minX)
                } else {
                    insets.leading = max(insets.leading, frame.maxX)
                }
            } else {
                if corner.vertical == .bottom {
                    insets.bottom = max(insets.bottom, size.height - frame.minY)
                } else {
                    insets.top = max(insets.top, frame.maxY)
                }
            }
        }
        return insets
    }
}

extension View {
    func readFold(_ layout: Binding<FoldLayout>) -> some View {
        modifier(FoldReader(layout: layout))
    }

    func clearOfReservedRegions(corner: Alignment, footprint: CGSize) -> some View {
        modifier(ReservedRegionInset(corner: corner, footprint: footprint))
    }
}
