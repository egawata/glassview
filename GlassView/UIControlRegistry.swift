/*
Copyright 2025 egawata

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import AppKit

// MARK: - UI Control Registry for Observer Pattern
@available(macOS 12.3, *)
class UIControlRegistry {
    private var registeredControls: [NSControl] = []
    private var alwaysEnabledControls: Set<NSControl> = []

    func register(_ control: NSControl, alwaysEnabled: Bool = false) {
        if !registeredControls.contains(control) {
            registeredControls.append(control)
            if alwaysEnabled {
                alwaysEnabledControls.insert(control)
            }
        }
    }

    func unregister(_ control: NSControl) {
        registeredControls.removeAll { $0 == control }
        alwaysEnabledControls.remove(control)
    }

    func setAllControlsEnabled(_ enabled: Bool, except excludedControls: [NSControl] = []) {
        for control in registeredControls {
            // alwaysEnabled が設定されているコントロールは除外条件に関係なく常に有効
            if alwaysEnabledControls.contains(control) {
                control.isEnabled = true
                control.alphaValue = 1.0
            } else if !excludedControls.contains(control) {
                control.isEnabled = enabled
                control.alphaValue = enabled ? 1.0 : 0.5
            }
        }
    }

    func getAllRegisteredControls() -> [NSControl] {
        return registeredControls
    }
}
