# Implementation Plan: Image Cropping & Editing Window

Add a dedicated UI for cropping and basic editing of profile pictures before they are uploaded to Cloudinary.

## User Review Required

> [!NOTE]
> - **Platform Support**: Using `crop_your_image`, a pure-Flutter solution, to ensure the cropping window works seamlessly on **Windows Desktop** as well as mobile/web.
> - **UI Flow**: After selecting an image from the gallery, a dialog will appear where the user can adjust the crop area (forced 1:1 ratio for profile pics) before confirming the upload.

## Proposed Changes

### 1. Data Models & Utilities

#### [MODIFY] [pubspec.yaml](file:///C:/Users/Kshitij/Desktop/songcatcher/pubspec.yaml)
- Already added `crop_your_image`.

### 2. New UI Components

#### [NEW] [image_crop_dialog.dart](file:///C:/Users/Kshitij/Desktop/songcatcher/lib/screens/home/widgets/image_crop_dialog.dart)
- A stateful dialog that takes raw image bytes and provides a cropping interface.
- Features:
    - Interactive crop area.
    - Zoom/Scale controls.
    - "Crop & Upload" and "Cancel" buttons.
    - Matches the **skribbl.io** theme (white background, solid borders).

### 3. Screen Integration

#### [MODIFY] [profile_screen.dart](file:///C:/Users/Kshitij/Desktop/songcatcher/lib/screens/home/profile_screen.dart)
- Update `_pickImage` to:
    1. Pick the image.
    2. Read bytes.
    3. Open `ImageCropDialog`.
    4. Receive cropped bytes.
    5. Pass cropped bytes to `UserService.uploadProfileImage`.

## Verification Plan

### Manual Verification
- **Windows Desktop**: Verify the cropping handles are responsive and the image can be zoomed/panned.
- **Aspect Ratio**: Ensure the output image is always a perfect square.
- **Upload Consistency**: Verify that the cropped image is exactly what appears on the profile after upload.
