shader_type spatial;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
render_mode unshaded;

uniform float zNear = 0.5;
uniform float zFar = 10.0;

void vertex() {
	// Called for every vertex the material is visible on.
  POSITION = vec4(UV*2.0-1.0, 0.0, 1.0);
}

void fragment() {
	// Called for every pixel the material is visible on.
  vec4 original = texture(SCREEN_TEXTURE, SCREEN_UV);

  float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
  vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 -1.0;
  vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
  view.xyz /= view.w;

  float linear_depth = -view.z;
  float scaled_depth = (zFar * zNear) / (zFar + (linear_depth * (zNear - zFar)));


  float depth_range = zFar - zNear;
  float depth_normalized = clamp((linear_depth - zNear) / depth_range, 0.0, 1.0);

  vec3 close = vec3(0.0, 0.0, 0.0);
  vec3 far = vec3(1.0, 1.0, 1.0);

  //vec3 color = mix(darkRed, blue, depth_normalized);
  float depth_normalized_exaggerated = pow(depth_normalized, 0.5); // Use a power curve to spread the gradient
  vec3 color = mix(close, far, depth_normalized);
  //ALBEDO = color;
  ALBEDO = color;

  //ALBEDO = original.rgb;
  //ALBEDO = vec3(scaled_depth);
  //ALBEDO = mix(gray, original.rgb, scaled_depth);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
