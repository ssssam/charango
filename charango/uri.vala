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

namespace Charango {

public void parse_string_as_resource (Charango.Context context,
                                      string           input,
                                      out Ontology?    ontology,
                                      out string?      fragment)
	        throws ParseError                                    {
	string uri_string;

	ontology = null;
	fragment = null;

	/* Expand namespace abbreviations */
	if (input.index_of_char ('/') == -1) {
		var colon_index = input.index_of_char (':');
		if (colon_index < 1) {
			warning ("Invalid URI: %s\n", input);
			return;
		}

		string prefix = input[0:colon_index];
		ontology = context.get_ontology_by_prefix (prefix);
		if (ontology == null) {
			throw new ParseError.UNKNOWN_NAMESPACE
			            ("Unknown prefix '%s' parsing %s\n", prefix, input);
		}

		if (colon_index < input.length - 1) {
			fragment = input[colon_index+1:input.length];
			uri_string = ontology.uri + fragment;
		} else
			uri_string = ontology.uri;
	} else
		uri_string = input;

	return_if_fail (uri_string != null);

	var hash_index = uri_string.last_index_of_char ('#');

	if (hash_index == -1)
		/* Some don't use the #fragment-identifier convention */
		hash_index = uri_string.last_index_of_char ('/');

	/* Check for invalid URI's */
	return_if_fail (hash_index > -1);
	return_if_fail (hash_index < uri_string.length - 1);

	var uri_namespace = uri_string [0: hash_index + 1];

	ontology = context.get_ontology_by_namespace (uri_namespace);
	if (ontology == null)
		throw new ParseError.UNKNOWN_NAMESPACE
		            ("Unable to find namespace for %s\n", uri_string);

	fragment = uri_string[hash_index + 1: uri_string.length];
}

public string? get_name_from_uri (string uri_string) {
	var hash_index = uri_string.last_index_of_char ('#');

	if (hash_index == -1)
		hash_index = uri_string.last_index_of_char ('/');

	/* Check for invalid URI's */
	return_val_if_fail (hash_index > -1, null);
	return_val_if_fail (hash_index < uri_string.length - 1, null);

	return uri_string[hash_index + 1: uri_string.length];
}

}