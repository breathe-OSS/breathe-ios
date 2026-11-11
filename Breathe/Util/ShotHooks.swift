// SPDX-License-Identifier: MIT
/*
 * ShotHooks.swift
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

#if DEBUG
import Foundation

enum ShotHooks {
    static var zone: String? {
        UserDefaults.standard.string(forKey: "shotZone")
    }

    static var scroll: String? {
        UserDefaults.standard.string(forKey: "shotScroll")
    }

    static var sheet: String? {
        UserDefaults.standard.string(forKey: "shotSheet")
    }

    static var screen: String? {
        UserDefaults.standard.string(forKey: "shotScreen")
    }

    static var history: String? {
        UserDefaults.standard.string(forKey: "shotHistory")
    }

    static var mapLayer: String? {
        UserDefaults.standard.string(forKey: "shotLayer")
    }

    static func nodeToOpen(in nodes: [String: NodeReading]?) -> String? {
        guard let nodes, let sheet else {
            return nil
        }
        let names = nodes.keys.sorted()
        let live = names.first { nodes[$0]?.pm25 != nil }
        let offline = names.first { nodes[$0]?.pm25 == nil }
        if sheet == "node" {
            return live ?? names.first
        }
        if sheet == "offlineNode" {
            return offline ?? names.first
        }
        return nil
    }
}
#endif
