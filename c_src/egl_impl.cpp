/*
 * %CopyrightBegin%
 * 
 * Copyright Ericsson AB 2010. All Rights Reserved.
 * 
 * The contents of this file are subject to the Erlang Public License,
 * Version 1.1, (the "License"); you may not use this file except in
 * compliance with the License. You should have received a copy of the
 * Erlang Public License along with this software. If not, it can be
 * retrieved online at http://www.erlang.org/.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.
 * 
 * %CopyrightEnd% 
 */

#include <stdio.h>
#include <string.h>

#include "egl_impl.h"

#define WX_DEF_EXTS
#include "gen/gl_fdefs.h"
#include "gen/gl_finit.h"
#include "gen/glu_finit.h"

void init_tess(); 
void exit_tess();
int load_gl_functions();

/* **************************************************************************** 
 * OPENGL INITIALIZATION 
 *****************************************************************************/

int egl_initiated = 0;

#ifdef _WIN32
void * dlsym(HMODULE Lib, const char *func) {
  void * funcp;
  if((funcp = (void *) GetProcAddress(Lib, func))) 
    return funcp;
  else 
    return (void *) wglGetProcAddress(func);
}
#endif 

int egl_init_opengl() 
{
  if(egl_initiated == 0) {
    if(load_gl_functions()) {
      init_tess();
      egl_initiated = 1;
    }
  }
  return 1;
}

int load_gl_functions() {
#ifdef _MACOSX
  char * DLName = "/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/libGL.dylib";
  void * LIBhandle = dlopen(DLName, RTLD_LAZY);
#elif defined(_WIN32)
  WCHAR * DLName = wxT("opengl32.dll");
  HMODULE LIBhandle = LoadLibrary(DLName);
#else 
  char * DLName = (char *) "libGL.so";
  void * LIBhandle = dlopen(DLName, RTLD_LAZY);
#endif
  // fprintf(stderr, "Loading GL: %s\r\n", (const char*)DLName);
  void * func = NULL;
  int i;

  if(LIBhandle) {
    for(i=0; gl_fns[i].name != NULL; i++) {
      if((func = dlsym(LIBhandle, gl_fns[i].name))) {
	* (void **) (gl_fns[i].func) = func;
	// fprintf(stderr, "GL LOADED %s \r\n", gl_fns[i].name);
      } else {
	if(gl_fns[i].alt != NULL) {
	  if((func = dlsym(LIBhandle, gl_fns[i].alt))) {
	    * (void **) (gl_fns[i].func) = func;
	    // fprintf(stderr, "GL LOADED %s \r\n", gl_fns[i].alt);
	  } else {
	    * (void **) (gl_fns[i].func) = (void *) &gl_error;
	    // fprintf(stderr, "GL Skipped %s and %s \r\n", gl_fns[i].name, gl_fns[i].alt);
	  };
	} else {
	  * (void **) (gl_fns[i].func) = (void *) &gl_error;
	  // fprintf(stderr, "GL Skipped %s \r\n", gl_fns[i].name);
	}
      }
    }
#ifdef _WIN32
    FreeLibrary(LIBhandle);
#else
    dlclose(LIBhandle);
#endif
    // fprintf(stderr, "OPENGL library is loaded\r\n");
  } else {
//     wxString msg;
//     msg.Printf(wxT("Could NOT load OpenGL library: "));
// #ifdef _WIN32
//     msg += DLName;
// #else
//     msg += wxString::FromAscii((char *)DLName);
// #endif
//     send_msg("error", &msg);
    fprintf(stderr, "Could NOT load OpenGL library: %s\r\n", DLName);
  };

#ifdef _MACOSX
  DLName = "/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/libGLU.dylib";
  LIBhandle = dlopen(DLName, RTLD_LAZY);
#elif defined(_WIN32)
  DLName = wxT("glu32.dll");
  LIBhandle = LoadLibrary(DLName);
#else 
  DLName = (char *) "libGLU.so";
  LIBhandle = dlopen(DLName, RTLD_LAZY);
#endif
  // fprintf(stderr, "Loading GL: %s\r\n", (const char*)DLName);
  func = NULL;

  if(LIBhandle) {
    for(i=0; glu_fns[i].name != NULL; i++) {      
      if((func = dlsym(LIBhandle, glu_fns[i].name))) {
	* (void **) (glu_fns[i].func) = func;
      } else {
	if(glu_fns[i].alt != NULL) {
	  if((func = dlsym(LIBhandle, glu_fns[i].alt))) {
	    * (void **) (glu_fns[i].func) = func;
	  } else {
	    * (void **) (glu_fns[i].func) = (void *) &gl_error;
	    // fprintf(stderr, "GLU Skipped %s\r\n", glu_fns[i].alt);
	  };
	} else {
	  * (void **) (glu_fns[i].func) = (void *) &gl_error;
	  // fprintf(stderr, "GLU Skipped %s\r\n", glu_fns[i].name);
	}
      }
    }
#ifdef _WIN32
    FreeLibrary(LIBhandle);
#else
    dlclose(LIBhandle);
#endif
    // fprintf(stderr, "GLU library is loaded\r\n");
  } else {
//     wxString msg;
//     msg.Printf(wxT("Could NOT load OpenGL GLU library: "));
// #ifdef _WIN32
//     msg += DLName;
// #else
//     msg += wxString::FromAscii((char *)DLName);
// #endif
//     send_msg("error", &msg);
    fprintf(stderr, "Could NOT load OpenGL GLU library: %s\r\n", DLName);
  };

  return 1;
}

void gl_error() {
  // int AP = 0; ErlDrvTermData rt[8];
  // rt[AP++] = ERL_DRV_ATOM; rt[AP++] = driver_mk_atom((char *)"_wxe_error_");
  // rt[AP++] = ERL_DRV_INT;  rt[AP++] = (int) gl_error_op;
  // rt[AP++] = ERL_DRV_ATOM; rt[AP++] = driver_mk_atom((char *)"undef");
  // rt[AP++] = ERL_DRV_TUPLE; rt[AP++] = 3;
  // driver_send_term(WXE_DRV_PORT,gl_active,rt,AP);
  // BUGBUG
  fprintf(stderr, "OpenGL Extension not available : %d\r\n", gl_error_op);
}

/* *******************************************************************************
 * GLU Tesselation special
 * ******************************************************************************/

static GLUtesselator* tess;
static GLdouble* tess_coords;
static GLdouble* tess_alloc_vertex;
static int* tess_vertices;

void CALLBACK
egl_ogla_vertex(GLdouble* coords)
{
  /* fprintf(stderr, "%d\r\n", (int) (coords - tess_coords) / 3); */

  *tess_vertices++ = (int) (coords - tess_coords) / 3;
}

void CALLBACK
egl_ogla_edge_flag(GLboolean flag)
{
}

void CALLBACK
egl_ogla_error(GLenum errorCode)
{
  const GLubyte *err;
  err = gluErrorString(errorCode);
  // wxString msg;
  // msg.Printf(wxT("Tesselation error:  %d: "), (int)errorCode);
  // msg += wxString::FromAscii((char *) err);
  // send_msg("error", &msg);
  fprintf(stderr, "Tesselation error: %d\r\n", (int) errorCode);
}

void CALLBACK
egl_ogla_combine(GLdouble coords[3],
		 void* vertex_data[4],
		 GLfloat w[4], 
		 void **dataOut)
{
  GLdouble* vertex = tess_alloc_vertex;

  tess_alloc_vertex += 3;

#if 0
  fprintf(stderr, "combine: ");
  int i;
  for (i = 0; i < 4; i++) {
    if (w[i] > 0.0) {
      fprintf(stderr, "%d(%g) ", (int) vertex_data[i], w[i]);
    }
  }
  fprintf(stderr, "\r\n");
  fprintf(stderr, "%g %g %g\r\n", vertex[0], vertex[1], vertex[2]);
#endif

  vertex[0] = coords[0];
  vertex[1] = coords[1];
  vertex[2] = coords[2];
  *dataOut = vertex;
}

void init_tess() 
{
  tess = gluNewTess();

  gluTessCallback(tess, GLU_TESS_VERTEX,     (GLUfuncptr) egl_ogla_vertex);
  gluTessCallback(tess, GLU_TESS_EDGE_FLAG,  (GLUfuncptr) egl_ogla_edge_flag);
  gluTessCallback(tess, GLU_TESS_COMBINE,    (GLUfuncptr) egl_ogla_combine);
  gluTessCallback(tess, GLU_TESS_ERROR,      (GLUfuncptr) egl_ogla_error);

}

void exit_tess() 
{
  gluDeleteTess(tess);
}

int erl_tess_impl(char* buff, ErlDrvPort port, ErlDrvTermData caller)
{
  ErlDrvBinary* bin;
  int i;
  GLdouble* new_vertices;
  int *vertices;
  int num_vertices;
  GLdouble *n;
  int n_pos, AP, res;
  
  num_vertices = * (int *) buff; buff += 8; /* Align */
  n = (double *) buff; buff += 8*3;

  bin = driver_alloc_binary(num_vertices*6*sizeof(GLdouble));  
  new_vertices = tess_coords = (double *) bin->orig_bytes;
  memcpy(tess_coords,buff,num_vertices*3*sizeof(GLdouble));
  tess_alloc_vertex = tess_coords + num_vertices*3;

#if 0
  fprintf(stderr, "n=%d\r\n", num_vertices);
#endif 
  vertices = (int *) driver_alloc(sizeof(int) * 16*num_vertices);
  
  tess_vertices = vertices;
  
  gluTessNormal(tess, n[0], n[1], n[2]);
  gluTessBeginPolygon(tess, 0);
  gluTessBeginContour(tess);
  for (i = 0; i < num_vertices; i++) {
    gluTessVertex(tess, tess_coords+3*i, tess_coords+3*i);
  }
  gluTessEndContour(tess);
  gluTessEndPolygon(tess);
    
  n_pos = (tess_vertices - vertices); 
  
  AP = 0; ErlDrvTermData *rt;
  rt = (ErlDrvTermData *) driver_alloc(sizeof(ErlDrvTermData) * (13+n_pos*2));
  rt[AP++]=ERL_DRV_ATOM; rt[AP++]=driver_mk_atom((char *) "_egl_result_");

  for(i=0; i < n_pos; i++) {
    rt[AP++] = ERL_DRV_INT; rt[AP++] = (int) vertices[i];
  };
  rt[AP++] = ERL_DRV_NIL; rt[AP++] = ERL_DRV_LIST; rt[AP++] = n_pos+1;

  rt[AP++] = ERL_DRV_BINARY; rt[AP++] = (ErlDrvTermData) bin; 
  rt[AP++] = (tess_alloc_vertex-new_vertices)*sizeof(GLdouble); rt[AP++] = 0;
  
  rt[AP++] = ERL_DRV_TUPLE; rt[AP++] = 2; // Return tuple {list, Bin}
  rt[AP++] = ERL_DRV_TUPLE; rt[AP++] = 2; // Result tuple
  
  res = driver_send_term(port,caller,rt,AP);
  /* fprintf(stderr, "List %d: %d %d %d \r\n",  */
  /* 	  res, */
  /* 	  n_pos,  */
  /* 	  (tess_alloc_vertex-new_vertices)*sizeof(GLdouble),  */
  /* 	  num_vertices*6*sizeof(GLdouble)); */
  driver_free_binary(bin);
  driver_free(vertices);
  driver_free(rt);
  return 0;
}
