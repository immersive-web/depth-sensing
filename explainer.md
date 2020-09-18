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
  requiredFeatures: [“depth”]
});
```

2. In requestAnimationFrame callback, query XRFrame for the currently available XRDepthInformation:

```javascript
const view = ...;  // Obtained from a viewer pose.
const depthInfo = frame.getDepthInformation(view);

if(depthInfo == null) {
  ... // Handle the case where current frame does not carry depth information.
}
```

3. Use the data:
  - CPU access:

```javascript
// Obtain the depth at (x, y) depth buffer coordinate:
const depthInMeters = depthInfo.getDepth(x, y);
```

Note: The depth buffer coordinates may not correspond to screen space
coordinates. To convert from depth buffer coordinates, the applications
can use depthData.normTextureFromNormView matrix. Pseudocode:

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

 - GPU access:

```javascript
const program = ...; // Linked WebGLProgam program.
const u_DepthTextureLocation = gl.getUniformLocation(program, "u_DepthTexture");
const u_UVTransformLocation = gl.getUniformLocation(program, "u_UVTransform");

// The application could upload the depth information like so:

// gl.TexImage2D expects Uint8Array when using gl.UNSIGNED_BYTE
const depthBuffer = new Uint8Array(dataBuffer.buffer,
                                   dataBuffer.byteOffset,
                                   dataBuffer.byteLength);
gl.bindTexture(gl.TEXTURE_2D, depthTexture);
gl.TexImage2D(GL_TEXTURE_2D, 0, gl.LUMINANCE_ALPHA, depthInfo.width,
              depthInfo.height, 0, gl.LUMINANCE_ALPHA, gl.UNSIGNED_BYTE,
              depthBuffer);

// Subsequently, we need to activate the texture unit (in this case, unit 0),
// and set depth texture sampler to 0:
gl.activeTexture(gl.TEXTURE0);
gl.uniform1i(u_DepthTextureLocation, 0);  // Location of the uniform variable
                                          // can be obtained by gl.

// In addition, the UV transform is necessary to correctly index into the depth map:
gl.uniformMatrix4fv(u_UVTransformLocation, false,
                    depthInfo.normTextureFromNormView.matrix);

```

The depth data available to the WebGL shaders will then be packed into luminance and alpha components of the texels. *Note*: data on the GPU is provided in millimetres.

In order to access the data in the shader, assuming the texture was bound to a texture unit as above, the applications can then use for example fragment shader:

```c++
precision mediump float;

uniform sampler2D u_DepthTexture;
uniform mat4 u_UVTransform;

varying vec2 v_TexCoord;  // Computed in vertex shader, based on vertex attributes.

float getDepthInMillimeters(in sampler2D depth_texture, in vec2 uv_coord) {
  // Depth is packed into the luminance and alpha components of its texture.
  // The texture is a normalized format, storing millimeters.
  vec2 packedDepth = texture2D(depth_texture, uv_coord).ra;
  return dot(packedDepth, vec2(255.0, 256.0 * 255.0));
}

void main(void) {
  vec2 texCoord = (u_UVTransform * vec4(v_TexCoord.xy, 0, 1)).xy;
  float depthInMillimeters = getDepthInMillimeters(u_DepthTexture, texCoord);

  gl_FragColor = ...;
}
```

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

```webidl
interface XRDepthInformation {
  readonly attribute Uint16Array data;

  readonly attribute unsigned long width;
  readonly attribute unsigned long height;

  [SameObject] readonly attribute XRRigidTransform normTextureFromNormView;

  float getDepth(unsigned long column, unsigned long row);
};

partial interface XRFrame {
  XRDepthInformation getDepthInformation(XRView view);
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