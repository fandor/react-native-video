## react-native-video

A `<Video>` component for react-native, as seen in
[react-native-login](https://github.com/brentvatne/react-native-login)!

Requires react-native >= 0.19.0

### Add it to your project

Run `npm i -S react-native-video`

#### iOS

Install [rnpm](https://github.com/rnpm/rnpm) and run `rnpm link react-native-video`.

If you would like to allow other apps to play music over your video component, add:

**AppDelegate.m**

```objective-c
#import <AVFoundation/AVFoundation.h>  // import

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  ...
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];  // allow
  ...
}
```

#### Android

Install [rnpm](https://github.com/rnpm/rnpm) and run `rnpm link react-native-video`

Or if you have trouble using [rnpm](https://github.com/rnpm/rnpm), make the following additions to the given files manually:

**android/settings.gradle**

```
include ':react-native-video'
project(':react-native-video').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-video/android')
```

**android/app/build.gradle**

```
dependencies {
   ...
   compile project(':react-native-video')
}
```

**MainActivity.java**

On top, where imports are:

```java
import com.brentvatne.react.ReactVideoPackage;
```

Under `.addPackage(new MainReactPackage())`:

```java
.addPackage(new ReactVideoPackage())
```

### Note: In react-native >= 0.29.0 you have to edit `MainApplication.java`

**MainApplication.java** (react-native >= 0.29.0)

On top, where imports are:

```java
import com.brentvatne.react.ReactVideoPackage;
```

Under `.addPackage(new MainReactPackage())`:

```java
.addPackage(new ReactVideoPackage())
```

## Usage

```javascript
// Within your render function, assuming you have a file called
// "background.mp4" in your project. You can include multiple videos
// on a single screen if you like.
<Video
  source={{uri: "background"}} // Can be a URL or a local file.
  rate={1.0}                   // 0 is paused, 1 is normal.
  volume={1.0}                 // 0 is muted, 1 is normal.
  muted={false}                // Mutes the audio entirely.
  paused={false}               // Pauses playback entirely.
  resizeMode="cover"           // Fill the whole screen at aspect ratio.
  repeat={true}                // Repeat forever.
  playInBackground={false}     // Audio continues to play when aentering background.
  playWhenInactive={false}     // [iOS] Video continues to play whcontrol or notification center are shown.
  onLoadStart={this.loadStart} // Callback when video starts to load
  onLoad={this.setDuration}    // Callback when video loads
  onProgress={this.setTime}    // Callback every ~250ms with currentTime
  onEnd={this.onEnd}           // Callback when playback finishes
  onError={this.videoError}    // Callback when video cannot be loaded
  style={styles.backgroundVideo}
/>

// Later on in your styles..
var styles = StyleSheet.create({
  backgroundVideo: {
    position: 'absolute',
    top: 0,
    left: 0,
    bottom: 0,
    right: 0,
  },
});
```

### Load files with the RN Asset System

The asset system [introduced in RN `0.14`](http://www.reactnative.com/react-native-v0-14-0-released/) allows loading local static resources using a `require` statement. As of version `react-native-video@0.9.0`, it's also be used to load video files in the same manner, e.g.

```
<Video
  repeat
  resizeMode='cover'
  source={require('../assets/video/turntable-loop-1920x500-h264-512kbps-h264.mp4')}
  style={styles.backgroundVideo}
/>
```

**Tip**: When loading files locally on iOS it's necessary to add static video file to the _Copy Bundle Resources_ section of _Build Phases_ for your project's build target in Xcode.

### Play in background on iOS

To enable audio to play in background on iOS the audio session needs to be set to `AVAudioSessionCategoryPlayback`. See [Apple documentation][3] for additional details.

## Static Methods

`seek(seconds)`

Seeks the video to the specified time (in seconds). Access using a ref to the component

## Examples

- See an [Example integration][1] in `react-native-login` *note that this example uses an older version of this library, before we used `export default` -- if you use `require` you will need to do `require('react-native-video').default` as per instructions above.*
- Try the included [VideoPlayer example][2] yourself:

   ```sh
   git clone git@github.com:brentvatne/react-native-video.git
   cd react-native-video/Examples/VideoPlayer
   npm install
   open VideoPlayer.xcodeproj

   ```

   Then `Cmd+R` to start the React Packager, build and run the project in the simulator.

- [Lumpen Radio](https://github.com/jhabdas/lumpen-radio) contains another example integration using local files and full screen background video.

## TODOS

- [ ] Add support for captions
- [ ] Add support for playing multiple videos in a sequence (will interfere with current `repeat` implementation)
- [ ] Callback to get buffering progress for remote videos
- [ ] Bring API closer to HTML5 `<Video>` [reference](http://devdocs.io/html/element/video#attr-poster)

[1]: https://github.com/brentvatne/react-native-login/blob/56c47a5d1e23781e86e19b27e10427fd6391f666/App/Screens/UserInfoScreen.js#L32-L35
[2]: https://github.com/brentvatne/react-native-video/tree/master/Examples/VideoPlayer
[3]: https://developer.apple.com/library/ios/qa/qa1668/_index.html

---

**MIT Licensed**
