# Build a great camera experience for iPhone Duo

Source: https://developer.apple.com/videos/play/tech-talks/111465/

Discover how to leverage the outer and inner cameras on iPhone Duo. Explore the Virtual Front Camera, and find out how to use the direction coordinator to switch between cameras and update your UI as people open and close iPhone Duo. Learn best practices for handling preview aspect ratios, positioning, and rotation to deliver a seamless capture experience.

## Chapters

- 0:00 - Introduction
- 0:31 - Meet the new front cameras
- 0:58 - Discover the virtual front camera
- 1:53 - Access each camera individually
- 2:46 - Track camera direction
- 4:03 - Create a direction coordinator
- 4:50 - Use both displays at once
- 5:38 - Work with device descriptors
- 6:17 - Handle a direction change
- 7:03 - Polish your camera preview
- 8:03 - Handle rotation
- 8:47 - Next steps

## Transcript

**0:04** Hi, my name is Tarun, and I'm from the camera software team.

**0:08** In this video, I'll cover the new camera features on iPhone Duo, and I'll go over how to build a great experience with them.

**0:15** I'll begin by introducing the new front cameras on iPhone Duo.

**0:19** Then I'll share how to handle camera direction changes when people open or close their device. Finally, I'll cover some tips that will polish your app's camera preview on iPhone Duo.

**0:30** Now, it's time to meet the iPhone Duo's new front cameras. iPhone Duo is the first iPhone to support two front cameras.

**0:39** Both of these cameras are square sensors with an ultrawide field of view. On the outside of the device, you'll find the outer ultrawide camera. It takes fantastic photos and videos. Open the device and you'll find the inner ultrawide camera, the first under-display camera on iPhone.

**0:57** Your app can stream from the front cameras through AVFoundation. Just like on any other iPhone, use the discovery session AVCaptureDeviceDiscoverySession to find the front camera.

**1:08** Request position .front, along with the Wide or Ultra Wide device type.

**1:14** When you do this on iPhone Duo, your app will now discover the new Virtual Front Camera.

**1:20** The Virtual Front Camera is a new AVCaptureDevice that automatically switches between the outer and inner physical cameras.

**1:27** When you have your iPhone Duo open, the Virtual Front Camera uses the front camera on the inner display.

**1:34** When you close your iPhone, the camera will automatically switch to the front camera on the outer display. The Virtual Front Camera uses the most relevant front camera for your app.

**1:45** The Virtual Front Camera handles the camera switch for you. But you can do even more by responding to camera direction changes.

**1:53** On iPhone Duo, each front camera has its own AVCaptureDevice type.

**1:58** Use the built-in outer ultrawide device type to access the front camera on the outer display.

**2:04** Use the built-in inner ultrawide device type to access the one on the inner display.

**2:10** When you use these device types, you get access to full capabilities of each camera. The inner ultrawide camera has 1080p video resolution with support up to 60fps. The outer ultrawide camera supports up to 4K resolution and 120fps. When your app uses the virtual front camera, you only have access to features common across both physical cameras. That is a max 1080p resolution and 60fps. It's also important to note that depth is only supported when accessing individual cameras.

**2:45** When you use individual cameras, your app is responsible for switching between them when someone opens or closes their iPhone Duo. Use the new AVCaptureDeviceDirectionCoordinator API to manage the transition.

**2:59** For some background, AVCaptureDevice has always provided a fixed position property. On iPhone, that has always been back or front. Both the inner and outer front cameras have the value front. But things get more interesting on iPhone Duo, where displays can face opposite directions. This would mean a front camera is not always looking at you. For example, you could be looking at the inner display, but be streaming from the outer front camera. In this case, a front camera is facing away from you.

**3:32** And while your app is streaming from the outer front camera, you might close the device. That same camera now swings to directly face you.

**3:40** If you flip the device while it's open, you can take a selfie with the back cameras. Now your app and the back camera are both directly facing you.

**3:51** To ensure your app always knows where the cameras are facing, use the direction coordinator. The direction coordinator tells your app where the cameras are and keeps you up to date as that changes.

**4:02** To create a direction coordinator, you need three things: your app's UIView, the device types you want to monitor, and a change handler.

**4:13** When your app's UIView is on the outer display, the coordinator will show outer display front cameras as forward-facing, and the rear cameras as backward-facing. When the device is opened, your app's UIView moves to the inner display. Your change handler will be called and will report the outer front and rear cameras as backward-facing cameras, and the inner front camera as forward-facing.

**4:37** If you flip the device while it's open, you can move a camera app to the outer display.

**4:43** When this happens, you'll find the rear and outer front camera both become forward-facing devices.

**4:49** On iPhone Duo, a camera app can use both displays at once. That's great for a group video call, or for showing a child something fun while you take their photo.

**4:59** In this situation, you will have two different UIViews for each display at the same time.

**5:05** One for the outer display and one for the inner display.

**5:10** Create a separate direction coordinator for each view. The outer display's coordinator will report the rear cameras as forward-facing, while the inner display's coordinator will report them as backward-facing. Each coordinator reports positions relative to its own view. Camera apps can enable this using the SceneAccessories API.

**5:31** Learn how in the video, "Leverage multiple displays and scenes on iPhone Duo." Because the direction coordinator is tied to a view, it is isolated to the main actor.

**5:43** Keep in mind that your change handler from the direction coordinator should not use AVFoundation APIs directly.

**5:51** Rather than handing you an AVCaptureDevice, the coordinator provides an AVCaptureDeviceDescriptor.

**5:58** The device descriptor is a main-actor-safe, sendable representation of an AVCaptureDevice.

**6:05** It contains all the information needed to create an AVCaptureDevice and can be safely passed to your camera actor.

**6:12** From there, you can interact with your AVFoundation APIs.

**6:16** Here's what you should do in your change handler.

**6:19** As someone opens or closes their device, your change handler will be called to tell your app which camera is now forward-facing.

**6:27** At this time, reconfigure your AVCaptureSession to keep streaming from the forward-facing camera.

**6:34** Consider how the new camera direction affects your decision to mirror the preview. When the rear camera is forward-facing, mirror the preview for a natural selfie camera experience. Finally, use the change handler to perform any UI updates while changing cameras. You'll find the direction coordinator in AVKit. More details about the coordinator can be found in the article, "Choosing a Camera by the Direction it Faces" in Apple's Developer Documentation.

**7:03** Now that we've gone over camera direction changes, I'll go over some tips to give your app a polished preview on iPhone Duo. When you stream using the full field of view of rear camera on inner display, you will have additional display space around your preview. Take advantage of this extra space by offsetting the preview, so you can group controls in the remaining space. Alternatively, you can have the preview fill the display. You have the flexibility to make the decision that's right for your app. Use the videoGravity property on AVCaptureVideoPreviewLayer to determine how to lay out your preview within the layer bounds. Check out the documentation for more details.

**7:44** When streaming from the ultrawide front cameras, you can fill the display by taking advantage of the square sensor. Use dynamicAspectRatio on AVCaptureDevice to select a landscape aspect ratio on the inner display.

**7:58** Learn more about the power of the square sensor in the video "Support the Center Stage Front Camera in your iOS app" from WWDC26.

**8:08** A final note on handling rotation in your app: Adopt the rotation coordinator to ensure your camera preview and photos always remain upright. On iPhone Duo, the rotation coordinator will update when your app moves displays.

**8:24** Use the coordinator to ensure your app's rotation is applied consistently across displays. Read the article "Supporting Device Rotation in Your Camera App" for more information about using the rotation coordinator.

**8:37** After adopting the rotation coordinator, disable camera-sensor-orientation compensation to improve performance. This compensation is enabled on all the front cameras on iPhone Duo.

**8:49** A few next steps. Use the iOS 27.1 SDK to take full advantage of iPhone Duo.

**8:57** Decide how your app will handle switching cameras when the device opens or closes.

**9:02** Adopt a direction coordinator if you want to move beyond the virtual front camera. Finally, test your app on iPhone Duo and make sure your camera preview looks great.

**9:12** I look forward to how your camera app unfolds on iPhone Duo.
