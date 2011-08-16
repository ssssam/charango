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

/* value.vapi: see value-internal.h for documentation */

namespace Charango {
	/* Basic literal types. These are separate from Charango's concept of the XSD and
	 * derived types, which are treated in the same way as RDFS classes.
	 */
	public enum ValueBaseType {
		RESOURCE,

		STRING,
		BOOLEAN,
		INT64,
		DOUBLE,
		DATE,
		DATETIME,

		FLOAT
	}

	public const string value_base_type_name[] = {
		"resource", "string", "boolean", "integer", "double", "date",
		"datetime", "float"
	};

	/* Charango.Value:
	 *  * immutable; always call free() when discarding a value (FIXME: is there
	 *    a way to get Vala to do this automatically?)
	 *  * no support for type information or an 'unset' state, you must track
	 *    this separately. So the pointer types are actually not nullable.
	 */
	/* Actually a union, but Vala does not support them */
	public extern struct Value {
		void *ptr;

		public extern Value.from_string (string v);
		public extern Value.from_boolean (bool v);
		public extern Value.from_int64 (int64 v);
		public extern Value.from_double (double v);
		public extern Value.from_date (GLib.Date v);
		public extern Value.from_datetime (GLib.DateTime v);
		public extern Value.from_float (float v);
		public extern Value.from_entity (Entity v);

		/* Helpfully, GDateTime is refcounted while GDate is not. Currently we
		 * return unowned references for both to avoid confusion.
		 * Note get_date() cannot actually return null, but Vala returns
		 * non-nullable structs by passing a pointer to the struct to be
		 * written to rather than by returning a pointer to the data.
		 */
		public extern unowned string get_string ();
		public extern bool get_boolean ();
		public extern int64 get_int64 ();
		public extern double get_double ();
		public extern unowned GLib.Date? get_date ();
		public extern unowned GLib.DateTime get_datetime ();
		public extern float get_float ();
		public extern Entity get_entity ();
	}

}
