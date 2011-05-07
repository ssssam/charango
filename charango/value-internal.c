/*  Charango
 *  Copyright 2011 Sam Thursfield <ssssam@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/* value-internal.c:
 * 
 * Charango's RDF value type system. We basically support xsd literals and user
 * defined subsets, and resources (whose type is known to Charango). A
 * CharangoValueType is a 32-bit int where the sign bit is set for resources and
 * unset for literals.
 *
 * This code is accessed from Vala via 'value.vala'.
 */

#include <glib.h>

typedef struct _CharangoEntity *CharangoEntity;

/* FIXME: It would be nice if these accessors could be macros. However, Vala
 * doesn't make it easy to include C code (we have to use the extern mechanism,
 * rather than a real .vapi file, because it does not support .vapi files that
 * extend the current namespace). It shouldn't be hard to fix Vala to support
 * doing this (the only reason it doesn't work is double definitions from
 * including the namespace header).
 * See also: http://www.mail-archive.com/vala-list@gnome.org/msg02882.html
 */

typedef enum {
	CHARANGO_VALUE_TYPE_RESOURCE = 0,

	/* Tracker's subset of the xsd data types */
	CHARANGO_VALUE_TYPE_STRING = 1,
	CHARANGO_VALUE_TYPE_BOOLEAN,
	CHARANGO_VALUE_TYPE_INTEGER,
	CHARANGO_VALUE_TYPE_DOUBLE,
	CHARANGO_VALUE_TYPE_DATE,
	CHARANGO_VALUE_TYPE_DATETIME,

	/* Other primitive types */
	CHARANGO_VALUE_TYPE_FLOAT
} CharangoValueBaseType;


typedef union {
	gint32  int32_value;
	float   float_value;

#if GLIB_SIZEOF_VOID_P >= 8
	gint64  int64_value;
	#define INLINE_INT64_VALUE

	gdouble double_value;
	#define INLINE_DOUBLE_VALUE
#endif

	void   *ptr;
} CharangoValue;


#ifdef INLINE_INT64_VALUE
	#define INT64_IS_INLINED  TRUE
#else
	#define INT64_IS_INLINED  FALSE
#endif

#ifdef INLINE_DOUBLE_VALUE
	#define DOUBLE_IS_INLINED  TRUE
#else
	#define DOUBLE_IS_INLINED  FALSE
#endif

 
/* xsd:string */
void charango_value_init_from_string (CharangoValue *value,
                                      const gchar   *x) {
	value->ptr = g_strdup (x);
}

const gchar *charango_value_get_string (CharangoValue *value) {
	return value->ptr;
}

/* xsd:boolean */
void charango_value_init_from_boolean (CharangoValue *value,
                                       gboolean       x) {
	value->int32_value = x;
}

gboolean charango_value_get_boolean (CharangoValue *value) {
	return value->int32_value;
}

/* xsd:integer  (unspecified size, I imagine everyone assumes 64bit) */
void charango_value_init_from_int64 (CharangoValue *value,
                                     gint64         x) {
#ifdef INLINE_INT64_VALUE
	value->int64_value = x;
#else
	value->ptr = g_slice_new (gint64);
	* ((gint64 *)value->ptr) = x;
#endif
}

gint64 charango_value_get_int64 (CharangoValue *value) {
#ifdef INLINE_INT64_VALUE
	return value->int64_value;
#else
	g_return_val_if_fail (value->ptr != NULL, 0);
	return * ((gint64 *) value->ptr);
#endif
}

/* xsd:double */
void charango_value_init_from_double (CharangoValue *value,
                                      gdouble        x) {
#ifdef INLINE_DOUBLE_VALUE
	value->double_value = x;
#else
	value->ptr = g_slice_new (gdouble);
	* ((gdouble *)value->ptr) = x;
#endif
}

double charango_value_get_double (CharangoValue *value) {
#ifdef INLINE_DOUBLE_VALUE
	return value->double_value;
#else
	g_return_val_if_fail (value->ptr != NULL, 0.0);
	return * ((gdouble *) value->ptr);
#endif
}

/* xsd:date */
void charango_value_init_from_date (CharangoValue *value,
                                    GDate         *x) {
	g_return_if_fail (g_date_valid (x));

	value->ptr = g_date_new ();
	g_date_set_julian ((GDate *)value->ptr, g_date_get_julian (x));
}

GDate *charango_value_get_date (CharangoValue *value) {
	return (GDate *) value->ptr;
}

/* xsd:dateTime */
void charango_value_init_from_datetime (CharangoValue *value,
                                        GDateTime     *x) {
	value->ptr = g_date_time_ref (x);
}

GDateTime *charango_value_get_datetime (CharangoValue *value) {
	return (GDateTime *) value->ptr;
}

/* xsd:int */
void charango_value_init_from_int32 (CharangoValue *value,
                                     gint32         x) {
	value->int32_value = x;
}

gint charango_value_get_int32 (CharangoValue *value) {
	return value->int32_value;
}

/* xsd:float */
void charango_value_init_from_float (CharangoValue *value,
                                     gfloat         x) {
	value->float_value = x;
}

gfloat charango_value_get_float (CharangoValue *value) {
	return value->float_value;
}

/* Any resource represented as an entity inside Charango (usually anything
 * with a class that's not part of an ontology definition)
 */
void charango_value_set_entity (CharangoValue  *value,
                                CharangoEntity *x) {
	g_object_ref (x);
	value->ptr = x;
}

CharangoEntity *charango_value_get_entity (CharangoValue *value) {
	return (CharangoEntity *) value->ptr;
}
