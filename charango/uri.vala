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

/* namespace_uris_match():
 * Match two namespace URIs, ignoring # or / terminators.
 */
public bool namespace_uris_match (string ns, string m) {
	char *ns_c = ns;
	char *m_c = m;

	while (*ns_c != '\0' && *m_c != '\0') {
		if (*ns_c != *m_c)
			break;

		ns_c ++; m_c ++;
	}

	if ((*ns_c=='\0' || ((*ns_c=='#' || *ns_c=='/') && *(ns_c+1)=='\0')) &&
		(*m_c=='\0' || ((*m_c=='#' || *m_c=='/') && *(m_c+1)=='\0')))
		return true;

	return false;
}

public void split_uri (string     uri,
                       out string namespace_uri,
                       out string fragment,
                       bool       allow_key_uri)
            throws RdfError                      {
	int split_index;

	namespace_uri = null;
	fragment = null;

	if (uri.index_of_char ('/') == -1) {
		split_index = uri.index_of_char (':');

		if (split_index <= 0 || split_index > uri.length - 1)
			throw new RdfError.URI_PARSE_ERROR ("Cannot understand \"%s\" as a URI.", uri);

		if (allow_key_uri == false)
			throw new RdfError.URI_PARSE_ERROR ("%s is not a full URI", uri);
	} else {
		split_index = uri.last_index_of_char ('#');

		if (split_index == -1)
			split_index = uri.last_index_of_char ('/');

		if (split_index <= 0 || split_index > uri.length - 1)
			throw new RdfError.URI_PARSE_ERROR ("Invalid URI: %s", uri);
	}

	namespace_uri = uri [0: split_index + 1];
	fragment = uri [split_index + 1: uri.length];
}

/*
public void parse_string_as_resource (Charango.Context context,
                                      string           input,
                                      out Ontology?    ontology,
                                      out string?      fragment)
            throws RdfError                                    {
	string uri_string;

	ontology = null;
	fragment = null;

	// Expand namespace abbreviations
	if (input.index_of_char ('/') == -1) {
		var colon_index = input.index_of_char (':');
		if (colon_index < 1)
			throw new RdfError.URI_PARSE_ERROR
			            ("parse_string_as_resource(): cannot parse %s", input);

		string prefix = input[0:colon_index];
		ontology = context.get_ontology_by_prefix (prefix);
		if (ontology == null)
			throw new RdfError.UNKNOWN_NAMESPACE
			            ("Unknown prefix '%s' parsing %s", prefix, input);

		if (colon_index < input.length - 1) {
			fragment = input[colon_index+1:input.length];
			uri_string = ontology.uri + fragment;
		} else
			uri_string = ontology.uri;
	} else
		uri_string = input;

	return_if_fail (uri_string != null);

	string ontology_namespace;
	parse_uri_as_resource_strings (uri_string, out ontology_namespace, out fragment);

	ontology = context.get_ontology_by_namespace (ontology_namespace);
	if (ontology == null)
		throw new RdfError.UNKNOWN_NAMESPACE
		            ("Unable to find namespace for %s", uri_string);
}
*/
/*
public string? get_namespace_from_uri (string uri_string) {
	var hash_index = uri_string.last_index_of_char ('#');

	if (hash_index == -1)
		hash_index = uri_string.last_index_of_char ('/');

	// Check for invalid URI's
	return_val_if_fail (hash_index > -1, null);
	return_val_if_fail (hash_index < uri_string.length - 1, null);

	return uri_string[0: hash_index + 1];

}*/

public string? get_name_from_uri (string uri) {
	var hash_index = uri.last_index_of_char ('#');

	if (hash_index == -1)
		hash_index = uri.last_index_of_char ('/');

	// Check for invalid URI's
	return_val_if_fail (hash_index > -1, null);

	if (hash_index >= uri.length - 1)
		return null;

	return uri[hash_index + 1: uri.length];
}

}
