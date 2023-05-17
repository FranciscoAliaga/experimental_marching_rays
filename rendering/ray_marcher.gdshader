shader_type canvas_item;

#include "./ray_marching.gdshaderinc"

// x horizontal
// y vertical
// z forward

/* parameters pulled from godot scene */
uniform vec3 camera_pos;
uniform mat3 camera_rotation;


/* parameters pulled from texture material */
uniform int x_pixels;
uniform int y_pixels;

uniform float reflection_index : hint_range(0.,1.);

uniform vec4 object_color : source_color;
uniform vec4 floor_color : source_color;
uniform vec4 sky_color : source_color;
uniform vec4 fog_color : source_color;


uniform float foggyness : hint_range(0.,1.);
uniform float fog_decay : hint_range(1.,100.);

// constants //

// for calculating derivatives
const float dh   = 0.01;
const float idh  = 1./dh;

// to assess if ray stopped near or far objects.
const float near = 0.01;
const float far  = 50.;

// algorithm parameters. Tweak these!
#define RAY_BOUNCES 4 // more -> more reflections. Needs to be at least 1. Less is faster.
#define JUMP_SEARCH 10 // bounce performance is improved with more. Less is faster.
#define JUMP_MULT 2. // bounce performance is improved if less (but step up jump search)

#define MAX_STEPS 35 // Maximum ray marching steps for each ray. less is faster, and near 10 it's quite aesthetical

// takes an uv coordinate from the screen renderer and
// returns the normalized ray.
vec3 ray(vec2 uv){
	// center uv
	vec2 uuvv = uv - vec2(0.5,0.5);
	// invert y coordinate
	uuvv.y *= -1.;
	// pass a ray through the {(x,y,z) : z=1} plane coming from the origin
	vec3 rd = vec3(uuvv,1.);
	// transform it according to camera
	rd = camera_rotation * rd;
	// return answer
	return normalize(rd);
}

/* Most important function */

// returns the Signed Distance Function; 
// each "object" is "declared" here. Reading SDFs is recommended prior to tweaking this.
// gets called several times from the ray marching algorithm
float get_sdf(vec3 pos, float t){
	// put a sphere at the center
	vec3 center = vec3(0.,-2.,5.);
	
	float sdf = 1000.;
	
	// put several bodies on a ring
	float r = 4.; // ring radius
	float RR = 0.7; // body radius
	int N = 4; // Number of figures
	for(int i = 0; i <N ; i++ ){
		float angle = 2.*PI*float(i)/float(N); // spinning,
		vec3 c_center = center + vec3(0.,0.,0.); // centered at
			// horizontal
		vec3 displacement_h = r*vec3(cos(angle+2.1*t),0.,sin(angle+2.*t));
			sdf = min(sdf,sphere_sdf(pos,c_center+displacement_h,RR));
			// vertical
		vec3 displacement_v = displacement_h.zxy;
			sdf = min(sdf,sphere_sdf(pos,c_center-displacement_v,RR));
	}
	sdf = exp_smin(sdf,cube_sdf(pos,center,vec3(0.7)),1.5);
	
	float s_r = .5*(0.8 + 0.1 * sin(10.*t));
	vec3 s_disp = vec3(0.,10.*cos(t*0.25),0.);
	sdf = exp_smin(sdf,sphere_sdf(pos,center+s_disp,s_r),2.);
	
	return sdf;
}

// Gradient of the SDF. Used for calculating normals (therefore bounces)
vec3 get_gradient(vec3 pos,float t){
	float dx = get_sdf(pos+vec3(dh,0.,0.),t) - get_sdf(pos,t) ;
	float dy = get_sdf(pos+vec3(0.,dh,0.),t) - get_sdf(pos,t) ;
	float dz = get_sdf(pos+vec3(0.,0.,dh),t) - get_sdf(pos,t) ;
	return vec3(dx,dy,dz)*idh;
}

// used to fetch colors.
// faraway stuff (given by high depth) gets background colors
// (sdf <= 1.5 near) represents solid objects
// everything else is just black.
// absolutely tweak this.
vec4 get_color(vec3 pos,float depth, float t){
	float sdf = get_sdf(pos,t);
	
	// faraway stuff gets colored with background: sky or floor color.
	if (sdf >= far){
		if (pos.y > 0.) return sky_color;
		else return floor_color;
	}
	
	return object_color;
}

/* A single Ray */
ray_march_hit ray_march(vec3 pos, vec3 ray, float t, bool first_ray){
	ray_march_hit result;
	result.depth = 0.;
	
	bool break_condition = false;
	int steps = 0;
	float d;
	
	float sdf = get_sdf(pos,t);
	
	if(first_ray){ // ray coming from camera
		d = sdf;
	} else { // ray bouncing out of a surface, the ray needs help getting out of the object:
		// find largest d such that gradient is increasing with ray.
		// this technique does not come from ray tracing literature, but from optimization.
		// Look for "Boyd Convex Optimization Book -> Algorithms - Linesearch".
		d = near;
		for(int j = 0; j<JUMP_SEARCH;j++){
			vec3 gradient  = get_gradient(pos+d*ray ,t); // "normal to surface vector"
			float projection = dot(ray,gradient);
			bool distance_increasing = projection > 0.;
			d*= JUMP_MULT;
			if (!distance_increasing){ // breaks once ray leaves the increasing distance zone.
				d /= JUMP_MULT;
				break;
			}
		}
	}
	
	// ray march
	do {
		result.depth += d;
		pos = pos + ray * d;
		d = get_sdf(pos,t);
		steps++;
		break_condition = (d <= 0.);
	} while ( (!break_condition) && (steps < MAX_STEPS  ));
	
	result.max_iterations = (steps>=MAX_STEPS);
	result.sdf      = d;
	result.position = pos;
	result.color  = get_color(pos,result.depth,t);
	return result;
}

/*   Algorithm   */

// Generates a ray, then bounces it RAY_BOUNCES times.
// The color is calculated mixing each bound, and the depth is the depth of the first ray.
color_and_depth ray_marching(vec3 pos, vec3 ray, float t){
	color_and_depth result;
	ray_march_hit[RAY_BOUNCES] hits;
	
	for(int i = 0; i < RAY_BOUNCES; i++){
		hits[i] = ray_march(pos,ray,t,(i==0));
		pos = hits[i].position;
		if(hits[i].sdf >= 2.*near) continue; // if the "hit" is far from an object, continue.
		// this code is only executed when the ray hits a surface
		ray = reflect_vector_plane(ray,get_gradient(pos,t));
	}
	float ff = foggyness* fog_ponderator_by_depth(hits[0].depth,fog_decay); // fog is applied depending on depth
	vec4 color = (1.-ff) * hits[0].color + ff*fog_color;
	for(int i = 1; i < RAY_BOUNCES; i++){
		// color mixing.
		ff = foggyness;// * fog_ponderator_by_depth(hits[i].depth,fog_decay);
		vec4 reflection_color = (1.-ff) * hits[i].color + (ff) * fog_color;
		color = (1.-reflection_index) * color + reflection_index * reflection_color;
	}
	
	result.color = color;
	result.depth = hits[0].depth;
	return result;
}

// Shader code. The outgoing camera rays are calculating using camera uniforms (position and rotation)
void fragment() {
	// camera position
	vec3 ro = camera_pos;
	
	// ray angle. 
	 vec3 rd = ray(pixel_uv(UV,ivec2(x_pixels,y_pixels))); // pixelation
	//	vec3 rd = ray(UV); // without pixelation
	
	// runs algorithm, gets color and depth.
	color_and_depth result = ray_marching(ro,rd,TIME);
	
	
	// color calculation;
	vec4 color = result.color;

	
	COLOR = color;
	COLOR.a = 1.;
}

