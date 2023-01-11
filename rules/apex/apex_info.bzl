"""
Copyright (C) 2022 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

ApexInfo = provider(
    "ApexInfo exports metadata about this apex.",
    fields = {
        "provides_native_libs": "Labels of native shared libs that this apex provides.",
        "requires_native_libs": "Labels of native shared libs that this apex requires.",
        "unsigned_output": "Unsigned .apex file.",
        "signed_output": "Signed .apex file.",
        "signed_compressed_output": "Signed .capex file.",
        "bundle_key_info": "APEX bundle signing public/private key pair (the value of the key: attribute).",
        "container_key_info": "Info of the container key provided as AndroidAppCertificateInfo.",
        "package_name": "APEX package name.",
        "backing_libs": "File containing libraries used by the APEX.",
        "symbols_used_by_apex": "Symbol list used by this APEX.",
        "java_symbols_used_by_apex": "Java symbol list used by this APEX.",
        "installed_files": "File containing all files installed by the APEX",
        "base_file": "A zip file used to create aab files.",
        "base_with_config_zip": "A zip file used to create aab files within mixed builds.",
    },
)
