# WebXR Depth API - explainer

## Introduction
As Augmented Reality becomes more common on the smartphone devices, new features are being introduced by the native APIs that enable AR-enabled experiences to access more detailed information about the environment in which the user is located. Depth API is one such feature, as it would allow authors of WebXR-powered experiences to obtain information about the distance from the user’s device to the real world geometry in the user’s environment.

One example of a tech demonstration of the Depth API running on a smartphone (Android): https://play.google.com/store/apps/details?id=com.google.ar.unity.arcore_depth_lab

## Use Cases
Given technical limitations of currently available native APIs, the main foreseen use case of the WebXR’s Depth API would be providing more believable interactions with the user's environment by feeding the depth map into the physics engine used. More advanced engines could leverage obtained depth data, along with the user’s pose, and attempt to reconstruct a more detailed map of the user’s environment.

Some specific examples and experiences that could be provided using the depth data for physics are:
- using the depth data for collision detection - projectiles burst when they hit a real world object, balls bounce off the furniture, virtual car hits a wall, etc
- using the depth data for path finding - robot navigates across a cluttered room

Secondary use case of the Depth API would be to provide applications with data that could be used for occlusion when rendering virtual objects. This use case is more sensitive to the quality of data, as any inaccuracies will likely be noticeable to the users. Depending on the provided depth buffer’s resolution and accuracy of data returned from the devices, the applications may choose not to leverage Depth API for this purpose. Therefore, the Depth API is not designed primarily with this use case in mind, but should be sufficiently flexible to be extended in the future.

## Consuming the API
1. Request the feature to be available on a session using its feature descriptor:

```javascript
const session = await navigator.xr.requestSession(“immersive-ar”, {
  requiredFeatures: [“depth-sensing”]
});
```

2. Configure the session to set the depth sensing usage and data format.

The application can query the user agent's preferred usage (`"cpu-optimized"` or `"gpu-optimized"`) and format (`"luminance-alpha"` or `"float32"`) by accessing `session.preferredDepthSensingUsage` & `session.preferredDepthFormat`:

```javascript
await session.updateDepthSensingState({
  usage: session.preferredDepthSensingUsage,
  depthFormat: session.preferredDepthFormat
});
```

Alternatively, the application can configure the depth sensing API using the usage and format that suits its needs, but that may result in the extra work done by the user agent in case the specified usage and format does not match the underlying platform's preferences.

In addition, only the `"luminance-alpha"` data format is guaranteed to be supported. User agents can optionally support more formats if they choose  so.

3. Within requestAnimationFrame() callback, query XRFrame for the currently available XRDepthInformation:

```javascript
const view = ...;  // Obtained from a viewer pose.
const depthInfo = frame.getDepthInformation(view);

if(depthInfo == null) {
  ... // Handle the case where current frame does not carry depth information.
}
```

**Note**: the depth information will not be retrievable until the session is successfully configured via the `updateDepthSensingState()` method.

4. Use the data. Irrespective of the usage, `XRDepthInformation` is only valid within the requestAnimationFrame() callback (i.e. only if the `XRFrame` is `active` and `animated`).
  - `"cpu-optimized"` usage mode:

```javascript
// Obtain the depth at (x, y) depth buffer coordinate:
const depthInMeters = depthInfo.getDepth(x, y);
```

**Note**: The depth buffer coordinates may not correspond to screen space
coordinates. To convert from depth buffer coordinates, the applications
can use `depthData.normTextureFromNormView` matrix. Pseudocode:

```js

const viewport = ...; // XRViewport obtained from XRWebGLLayer
const normViewFromNormTexture = depthInfo.normTextureFromNormView.inverse.matrix;

// Normalize depth buffer coordinates (x, y) to range [0...1]:
const depth_coordinates_texture_normalized = [x / depthInfo.width, y / depthInfo.height];
// Transform to normalized view coordinates (with the origin in lower left corner of the screen),
// using your favorite matrix multiplication library:
const depth_coordinates_view_normalized = normViewFromNormTexture * depth_coordinates_normalized;
// Denormalize from [0..1] using viewport dimensions:
const depth_coordinates_view = [depth_coordinates_view_normalized[0] * viewport.width,
                                depth_coordinates_view_normalized[1] * viewport.height];

// (x,y) depth buffer coordinates correspond to (depth_coordinates_view[0], depth_coordinates_view[1])
// coordinates
```

Alternatively, the depth data is also available via the `depthInfo.data` attribute. The entries are stored in a row-major order, and the entry size & data format is determined by the depth format set when configuring depth sensing API. The raw values obtained from the buffer can be converted to meters by multiplying the value by `depthInfo.rawValueToMeters`.

For example, to access the data at row `r`, column `c` of the buffer that has `"luminance-alpha"` format, the app can use:
```js
const index = c + r * depthInfo.width;
const depthInMetres = depthInfo.data.getUint16(index) * depthInfo.rawValueToMeters;
```

If the data format was set to `"float32"`, the data could be accessed similarly (note that the only difference is the `getFloat32()` method used on a `DataView` instance):
```js
const index = c + r * depthInfo.width;
const depthInMetres = depthInfo.data.getFloat32(index) * depthInfo.rawValueToMeters;
```

Both of the above examples are equivalent to calling `depthInfo.getDepth(c, r)`.

**Note**: `XRDepthInformation`'s `data`, `width` & `height` attributes, and `getDepth()` method are only accessible if the depth API was configured with mode set to `"cpu-optimized"`.

 - `"gpu-optimized"` mode:

```javascript

const xrWebGLBinding = ...; // XRWebGLBinding created for the current session and GL context

// Grab the information from the XRDepthInformation interface:
const uvTransform = depthInfo.normTextureFromNormView.matrix;

const program = ...; // Linked WebGLProgam program.
const u_DepthTextureLocation = gl.getUniformLocation(program, "u_DepthTexture");
const u_UVTransformLocation = gl.getUniformLocation(program, "u_UVTransform");
const u_RawValueToMeters = gl.getUniformLocation(program, "u_RawValueToMeters");

// The application can access upload the depth information like so:
const depthTexture = xrWebGLBinding.getDepthTexture(depthInfo);

gl.bindTexture(gl.TEXTURE_2D, depthTexture);

// Subsequently, we need to activate the texture unit (in this case, unit 0),
// and set depth texture sampler to 0:
gl.activeTexture(gl.TEXTURE0);
gl.uniform1i(u_DepthTextureLocation, 0);

// In addition, the UV transform is necessary to correctly index into the depth map:
gl.uniformMatrix4fv(u_UVTransformLocation, false,
                    uvTransform);

// ... and we also need to send the scaling factor to convert from the raw number to meters:
gl.uniform1f(u_RawValueToMeters, depthInfo.rawValueToMeters);
```

The depth data available to the WebGL shaders will then be packed into luminance and alpha components of the texels.

In order to access the data in the shader, assuming the texture was bound to a texture unit as above, the applications can then use for example fragment shader. The below code assumes that `"luminance-alpha"` was configured as the data format:

```c++
precision mediump float;

uniform sampler2D u_DepthTexture;
uniform mat4 u_UVTransform;
uniform float u_RawValueToMeters;

varying vec2 v_TexCoord;  // Computed in vertex shader, based on vertex attributes.

float getDepth(in sampler2D depth_texture, in vec2 uv_coord) {
  // Depth is packed into the luminance and alpha components of its texture.
  // The texture is a normalized format, storing millimeters.
  vec2 packedDepth = texture2D(depth_texture, uv_coord).ra;
  return dot(packedDepth, vec2(255.0, 256.0 * 255.0)) * u_RawValueToMeters;
}

void main(void) {
  vec2 texCoord = (u_UVTransform * vec4(v_TexCoord.xy, 0, 1)).xy;
  float depthInMeters = getDepth(u_DepthTexture, texCoord);

  gl_FragColor = ...;
}
```

**Note**: `XRWebGLBinding`'s `getDepthTexture()` method will only return a result if the depth API was configured with mode set to `"gpu-optimized"`. Also note that it is possible for the application to configure the depth API using a data format that cannot be uploaded to the GPU with the provided binding (for example, `"float32"` data format on a WebGL1 context).

### Interpreting the data

The returned depth value is a distance from the camera plane to the observed real-world geometry, at a given coordinate of the depth image. See below image for more details - the depth value at point a corresponds to the distance of point A from depth image plane (specifically, it is not the length of vector aA):

<p align="center">
  <img src="https://raw.githubusercontent.com/immersive-web/depth-sensing/main/img/depth_api_data_explained.png" alt="Depth API data explanation" width="557">
</p>

```javascript
let depthValueInMeters = depthInfo.getDepth(x, y);
  // Where x, y - image coordinates of point a.
```

## Appendix: Proposed Web IDL

The comments are left in place to provide additional context on the API to the readers of the IDL and should also be repeated in the explainer text above.

```webidl
enum XRDepthSensingUsage {
  "cpu-optimized",
  "gpu-optimized"
};

enum XRDepthDataFormat {
  // Has to be supported everywhere:
  "luminance-alpha", // internal_format = LUMINANCE_ALPHA, type = UNSIGNED_BYTE,
                     // 2 bytes per pixel, unpack via dot([R, A], [255.0, 256*255.0])
  // Other formats do not have to be supported by the user agents:
  "float32",         // internal_format = R32F, type = FLOAT
};

// At session creation, the depth sensing API needs to be configured
// with the desired usage and data format. The user agent will first select
// the lowest-indexed depth sensing usage that it supports, and then attempt
// to select the lowest-indexed depth data format. If the user agent is
// unable to select usage and data format that it supports, the depth sensing
// will not be enabled on a session - for sessions where depth sensing is
// listed as required feature, the session creation will fail.
dictionary XRDepthSensingStateInit {
  sequence<XRDepthSensingUsage> depthSensingUsagePreference;
  sequence<XRDepthDataFormat> depthDataFormatPreference;
};

partial interface XRSession {
  // Non-null iff depth-sensing is enabled:
  readonly attribute XRDepthDataFormat? depthDataFormat;
  readonly attribute XRDepthSensingUsage? depthSensingUsage;
};

partial interface XRFrame {
  // Throws if depth sensing state was never updated,
  // returns null if the view does not have a corresponding depth buffer.
  XRDepthInformation? getDepthInformation(XRView view);
};

[SecureContext, Exposed=Window]
interface XRDepthInformation {
  // All methods / attributes are accessible only when the frame
  // that the depth information originated from is active and animated.

  [SameObject] readonly attribute DataView data;
  readonly attribute unsigned long width;
  readonly attribute unsigned long height;

  float getDepth(unsigned long column, unsigned long row);

  // Must be valid irrespective of initialization hint:
  [SameObject] readonly attribute XRRigidTransform normTextureFromNormView;
  readonly attribute float rawValueToMeters;
};

partial interface XRWebGLBinding {
  // Must succeed when the depth API was initialized as "gpu-optimized". Otherwise, must throw.
  // Returns opaque texture, its format is determined by the current depth sensing state.
  WebGLTexture? getDepthTexture(XRDepthInformation depthInformation);
};
```

## Appendix: References
Existing or planned native APIs that should be compatible with the API shape proposed above:
- ARKit’s Depth API

https://developer.apple.com/documentation/arkit/ardepthdata
- ARCore Depth API

https://developers.google.com/ar/develop/java/depth/overview

https://developers.google.com/ar/reference/c/group/frame#arframe_acquiredepthimage

It is TBD how the Depth API could be implemented for other devices. For devices / runtimes that provide more detailed world mesh information, the Depth API implementation could leverage the world mesh and synthesize the depth data out of it. Alternatively, there may be ways of accessing the depth data directly (see for example: https://docs.microsoft.com/en-us/windows/mixed-reality/research-mode).
