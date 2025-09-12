To update a forked a BCR module:

Checkout the BCR git repo.

cp -r the new version that you want from BCR to the local registry.

Append .aemu to the version directory name and to the module name in the MODULE.bazel file.

Copy any aemu_...patch patch files from the previous version to the new one and
update the source.json file to apply them.


