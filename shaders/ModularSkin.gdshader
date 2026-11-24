shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Select warm, bright pixels on the starter-body texture. Dark clothes stay intact.
uniform sampler2D body_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 skin_tone : source_color = vec4(0.76, 0.46, 0.34, 1.0);
void fragment(){
 vec4 base=texture(body_texture,UV);
 float mask=smoothstep(0.08,0.17,base.r-base.b)*smoothstep(0.018,0.055,base.g-base.b)*smoothstep(0.17,0.33,base.r);
 vec3 changed=clamp(base.rgb*skin_tone.rgb/vec3(0.755,0.455,0.345),vec3(0.0),vec3(1.0));
 ALBEDO=mix(base.rgb,changed,mask);
 ALPHA=base.a;
 ROUGHNESS=0.78;
}
