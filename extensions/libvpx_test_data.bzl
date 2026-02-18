"""Module extension and repository rule to fetch libvpx test vectors in parallel."""

_DOWNLOAD_SCRIPT = """
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

def download_file(args):
    url, output = args
    if os.path.exists(output):
        return
    try:
        with urllib.request.urlopen(url) as response, open(output, "wb") as out_file:
            out_file.write(response.read())
    except Exception as e:
        print(f"Failed to download {url}: {e}")

if __name__ == "__main__":
    base_url = sys.argv[1]
    files = sys.argv[2:]
    tasks = [(f"{base_url}{f}", f) for f in files]

    # Use 16 threads for parallel downloading
    with ThreadPoolExecutor(max_workers=16) as executor:
        list(executor.map(download_file, tasks))
"""

def _libvpx_test_data_repo_impl(repository_ctx):
    sha1_file = repository_ctx.path(repository_ctx.attr.sha1_file)
    content = repository_ctx.read(sha1_file)

    base_url = "https://storage.googleapis.com/downloads.webmproject.org/test_data/libvpx/"

    file_list = []
    for line in content.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(" *")
        filename = parts[1] if len(parts) == 2 else line.split()[1]
        file_list.append(filename)

    repository_ctx.report_progress("Preparing parallel download of %d vectors" % len(file_list))
    repository_ctx.file("download.py", _DOWNLOAD_SCRIPT)

    # Use the system python or prebuilt python to run the parallel downloader
    # This is much faster than serial repository_ctx.download calls
    res = repository_ctx.execute(["python3", "download.py", base_url] + file_list)
    if res.return_code != 0:
        fail("Failed to download test vectors: %s" % res.stderr)

    # Create a BUILD file that exposes all downloaded files
    build_content = "package(default_visibility = ['//visibility:public'])\n\n"
    build_content += "filegroup(\n"
    build_content += "    name = 'vectors',\n"
    build_content += "    srcs = glob(['**/*'], exclude=['download.py', 'BUILD.bazel']),\n"
    build_content += ")\n"

    repository_ctx.file("BUILD.bazel", build_content)

libvpx_test_data_repo = repository_rule(
    implementation = _libvpx_test_data_repo_impl,
    attrs = {
        "sha1_file": attr.label(mandatory = True, allow_single_file = True),
    },
)

def _libvpx_test_data_extension_impl(module_ctx):
    libvpx_test_data_repo(
        name = "libvpx_test_vectors",
        sha1_file = "//third_party/libvpx:libvpx/test/test-data.sha1",
    )
    return module_ctx.extension_metadata(reproducible = True)

libvpx_test_data = module_extension(
    implementation = _libvpx_test_data_extension_impl,
)
