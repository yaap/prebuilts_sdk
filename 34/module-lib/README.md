## Updated since finalization

The android-plus-updatable.jar has been added to this directory after
finalization as the android.jar in this directory does not include updatable
modules. That is because doing so in the source would lead to dependency cycles
and the prebuilts have to match the source structure so that apps can build
against either prebuilts or sources.

The lack of updatable modules in android.jar caused problems for the
api-version.xml generation as that requires a single jar containing all the
APIs for each surface of each API version. See b/337836752 for more
information.
