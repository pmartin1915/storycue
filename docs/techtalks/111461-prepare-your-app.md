# Prepare your app for iPhone Duo

Source: https://developer.apple.com/videos/play/tech-talks/111461/

Learn how to update and optimize your app for the foldable display of iPhone Duo. Discover how to opt in to the full-screen experience, adopt flexible layout best practices, and simulate poses in Device Hub with Xcode. Find out how to use size classes instead of interface orientation, handle asymmetric safe areas, and test Split View multitasking to ensure your app shines in all the ways people use it.

## Chapters

- 0:00 - Introduction
- 0:30 - Build with the latest SDK
- 1:17 - Get started in Xcode
- 1:33 - Adopt flexible layouts
- 2:46 - Use size classes
- (remaining chapters not captured in About tab excerpt)

## Transcript

**0:04** Hi, I'm David Jackson, an engineering manager on the UI Frameworks team. Today, I'll cover how to bring your app to iPhone Duo. First, I'll tell you how to get started in Xcode.

**0:16** Next, I'll walk through general layout guidance to make your app resize correctly on any platform.

**0:22** Then, I'll tell you about specific layout guidance for iPhone Duo to make your app truly shine.

**0:28** Let's get started.

**0:30** Your app will work on iPhone Duo even if you haven't built it with the iOS 27 SDK. When the device is closed, your app will use the screen space to the left of the status bar and camera. When the device is open, your app will be a familiar size and aspect ratio. Here's how to take more advantage of the available screen space. If you've already adopted the iOS 27 SDK, the work you've done to support iPhone app resizing really pays off. Now your app will look like this. Your app will extend to the left of the status bar area on the inner display.

**1:02** And here's how to take advantage of the entire screen space. When you build your app with the iOS 27.1 SDK, your app extends to the edge of the screen. Standard navigation and toolbar buttons now lay out vertically under the status bar.

**1:17** To get the full-screen experience, download Xcode 27.1. Choose the iPhone Duo simulator to run your app in Device Hub. Use the control buttons at the bottom of the screen to open, close, rotate, or fold iPhone Duo.

**1:32** Now that your app is using the full screen space, you may notice some issues with your layout in each pose. A great iPhone Duo app follows flexible layout best practices we've discussed in the past. Most recently, we covered flexible layout principles during the talk, "Modernize Your UIKit App" from WWDC26. These principles matter more than ever for iPhone Duo, as your app will need to resize to fit every pose, opened, closed, rotated, or folded.

**2:00** iPhone apps have been adapting to change for a long time. They've adapted to new screen sizes, screen shapes, and special regions like the Dynamic Island. iPhone Duo continues along that path with a new screen shape and camera location.

**2:15** With iOS 27, people can resize your app larger than ever before using iPhone Mirroring on the Mac.

**2:22** Opening and closing iPhone Duo works the same way. Your app may react to different size class boundaries, but it is still an iPhone app.

**2:30** The best app layouts are adaptive across a continuum of devices. They avoid making assumptions about display sizes or device capabilities based on user interface idioms. And they use tools like size classes to differentiate between small and large layouts. Let's talk more about size classes.

**2:47** Horizontal and vertical size classes are loosely tied to the available space in their given dimensions. Size classes express the user experience your app should provide based on the available space. For SwiftUI, use the environment. For UIKit, use trait collection.

**3:04** On iPhone Duo, there are several size class combinations.

**3:07** On the outer display, like other iPhone models, iPhone Duo has regular vertical size class and compact horizontal size class in portrait, and compact vertical and horizontal size classes in landscape.

**3:20** On the inner display, the additional space lets you show more content like sidebars. As such, it has regular horizontal and vertical size classes. The interface orientation on the outer display behaves like any other iPhone. iPhone Duo is a great opportunity to support landscape orientation, as people may want to set the phone down like a tent.

**3:42** Interface orientation on the inner display behaves differently. The inner display doesn't honor your supported interface orientations. As with Idiom, avoid checking interface orientation for layout decisions. Use size classes instead.

**3:57** On a device with two displays, avoid referencing the main screen in your code. It's ambiguous and will be deprecated in a future release. If possible, don't use screen references at all. Instead, use more local concepts like the environment, trait collection, or the scene's bounds. If you need access to the screen, access it dynamically from the window scene.

**4:18** To make sure your UI fits the corners of the screen perfectly, use Concentricity APIs introduced in iOS 26. They're updated to work with the screen shapes on iPhone Duo.

**4:29** For SwiftUI, use ConcentricRectangle. For UIKit, use UICornerConfiguration.

**4:37** iPhone Duo will continue to honor the UIRequiresFullScreen key, but your app will still resize when someone opens or closes their iPhone Duo.

**4:45** iPhone Duo respects your supported interface orientations, but your app will scale on the inner display, including in Split View multitasking.

**4:53** For more on iPhone Duo screens, see the companion Tech Talk, "Leverage multiple displays and scenes on iPhone Duo." Now that your app is resizing to fit the inner and outer displays, I'll talk about unique layout considerations for iPhone Duo.

**5:08** Using standard navigation patterns is a great way to adapt to every iPhone Duo pose. SwiftUI's NavigationSplitView or UIKit's UISplitViewController are fully adaptive.

**5:19** When iPhone Duo is closed, columns will collapse to single-stack navigation. When open, columns will appear both tiled and as overlays. SwiftUI's TabView and UIKit's UITabBarController also adapt to all poses.

**5:34** By default, tabs will appear on the inner and outer display, laying out vertically when appropriate.

**5:39** On the inner display, you can opt into a sidebar with richer navigation. For SwiftUI, set the default tab bar placement to sidebar. For UIKit, set the preferred placement to sidebar.

**5:51** Sheets also adapt to all poses. On the outer display, sheets can have buttons that lay out vertically. On the inner display, sheets are centered. Other presentations like popovers, context menus, and alerts also adapt to each pose.

**6:05** Navigation bars, toolbars, and tab bars lay out outside the safe area. They automatically avoid system UI like the status bar and hardware features like the camera.

**6:15** Horizontal bars provide top and bottom insets, while vertical bars provide leading and trailing insets.

**6:22** For a deep dive on vertically arranged content, check out the companion tech talk, "Raise the Bar with iPhone Duo".

**6:29** Respecting safe areas ensures your app's controls are reachable and your app is fully visible. Here's how to best adopt safe areas in your app.

**6:37** When positioning your UI, make sure to place foreground elements like interactive controls within the safe area. For SwiftUI, your content is placed within the safe area by default. For UIKit, if you are laying out views manually, reference the view's safe area insets, or use Auto Layout to constrain the views to the safe area layout guide.

**6:59** Allow background elements such as full-bleed artwork to fill the available space, extending behind toolbars and sidebars.

**7:06** For SwiftUI, use ignoresSafeArea. For UIKit, use the view's bounds.

**7:12** Keep in mind that safe areas are often asymmetric. This is especially true on iPhone Duo. For example, vertical buttons can appear on the left side in landscape and Split View multitasking.

**7:25** As such, avoid assuming that insets on opposite sides are equal.

**7:29** Instead, write code that handles each side independently.

**7:33** As with safe areas, layout margins are also asymmetric. This lets your foreground content get closer to vertical buttons and the status bar, while preserving the margin on the opposite side.

**7:44** It's important to test your handling of safe areas in different configurations. Split View multitasking is no exception. Using Device Hub, preview your app on the inner display. Drag your app using the home indicator at the bottom to one side of the screen. An area to drop your app appears.

**8:01** Then, drag your app to the other side.

**8:04** Vertically laid-out content can appear on either side of your app.

**8:08** Lastly, in iOS 27.1, we're introducing a new API that lets your custom UI use as much of the available screen space as possible without colliding with system-provided UI.

**8:19** For SwiftUI, use ReservedRegion to safely position UI elements outside the safe area while maximizing usable space.

**8:27** For UIKit, it's called UIViewReservedRegion.

**8:31** This is a great option for building your own custom bars or when implementing edge-to-edge UI.

**8:37** For more information on reserved regions, including how you can use them to build custom UI that adapts to the fold, see the companion Tech Talk, "Strike a Pose with Adaptive Layouts on iPhone Duo." To summarize safe area best practices, use standard bars for UI that automatically adapts to the safe area. Align your interactive or visible foreground content to the safe area, while background content may extend past the safe area. Make sure to account for, and test, asymmetrical safe areas and layout margins. If you have more complex layouts, consider using reserved regions.

**9:12** I covered a lot of adaptive layout best practices. Here's an efficient way to make sure your app follows all of them.

**9:19** During the talk, Modernize Your UIKit App, we introduced a new app modernization skill.

**9:24** With Xcode 27.1, this skill has a new name: App Resizability. It now supports SwiftUI and iPhone Duo. Give it a try.

**9:35** Now your app is ready to feel right at home on iPhone Duo.

**9:38** To recap, download Xcode 27.1, simulate your app on iPhone Duo using Device Hub, make sure your app follows all the adaptive layout best practices I covered, and try out the App Resizability skill.

**9:52** And that's it. Thank you so much for your time. I look forward to seeing your iPhone Duo app above the fold on the App Store.
