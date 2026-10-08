// Copyright 2026 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//! Minimal Rust cdylib fixture for validating Breakpad symbol extraction.

#[inline(never)]
fn internal_rust_helper(value: i32) -> i32 {
    value.wrapping_mul(3).wrapping_add(7)
}

#[no_mangle]
pub extern "C" fn rust_symbol_fixture_compute(input: i32) -> i32 {
    internal_rust_helper(input) ^ 0x5a5a
}
