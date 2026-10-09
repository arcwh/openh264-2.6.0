# OpenH264 Android

This project contains the OpenH264 2.6.0 source code and a build script for building OpenH264 as Android libraries.

Upstream repository: https://github.com/cisco/openh264

## Build Environment

Example build environment:

- macOS (the build script only supports macOS hosts)
- Android NDK: r28c
- OpenH264: 2.6.0

You may replace the versions above according to your local environment.

## Supported Architectures

- armeabi-v7a
- arm64-v8a

## Build Instructions

The whole build is done by `build_openh264_android.sh` in the project root. You only need to adjust a few settings in the script and run it.

### 1. Configure the Build Script

Open `build_openh264_android.sh` and update the following variables at the top of the file:

```bash
NDK="/Users/anathan/Documents/android-ndk-r28c"   # Path to the Android NDK on your machine
API=23                                            # Minimum Android API level (minSdk) of the libraries
```

- `NDK`: **Must** be changed to the Android NDK path on your machine, e.g. `/Users/yourname/Library/Android/sdk/ndk/28.2.xxxxxxx`.
- `API`: The minimum Android API level of the generated libraries. It should not be higher than the `minSdk` of the app that uses them.

The script also checks the following, and stops with an error if any check fails:

- The NDK LLVM toolchain exists in `$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin`.
- `/usr/bin/make` (the macOS system make) is available. Install the Xcode Command Line Tools with `xcode-select --install` if it is missing.

### 2. Grant Execute Permission

```bash
chmod +x build_openh264_android.sh
```

### 3. Build Libraries

```bash
./build_openh264_android.sh
```

The script builds `armeabi-v7a` and `arm64-v8a` in sequence. To build only one ABI, edit the `ABIS` array near the end of the script.

## Build Output

After a successful build, the output is located in the `android/` directory of the project root:

```text
android/
├── armeabi-v7a/
│   ├── include/
│   │   └── wels/
│   │       ├── codec_api.h
│   │       ├── codec_app_def.h
│   │       ├── codec_def.h
│   │       └── codec_ver.h
│   └── lib/
│       ├── libopenh264.so
│       ├── libopenh264.a
│       └── pkgconfig/
│           └── openh264.pc
└── arm64-v8a/
    └── (same layout as armeabi-v7a)
```

- `lib/libopenh264.so`: Shared library.
- `lib/libopenh264.a`: Static library.
- `include/wels/`: Public headers.
- `lib/pkgconfig/openh264.pc`: pkg-config file, e.g. for linking OpenH264 when building FFmpeg.

Use either the shared library or the static library depending on your integration.

## Notes

- Do **not** run `make OS=android clean` manually. OpenH264's Android `clean` target invokes `ndk-build` and Gradle, and may trigger the quarantined NDK bundled make on macOS. The script cleans the build artifacts by itself before building each ABI.
- The `android/<ABI>/` output directory is deleted and regenerated on every build.
- The `prefix` in `openh264.pc` is the absolute output path on the build machine. Update it if you move the output to another directory.

## License

OpenH264 is licensed under the BSD 2-Clause License. See the `LICENSE` file for details.

OpenH264 copyright belongs to Cisco Systems.

For more information about OpenH264:

https://www.openh264.org/
