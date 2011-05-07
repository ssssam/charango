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

using Rdf;

/* These are really programmer errors rather than runtime exceptions,
 * because the ontologies are of course API. However, using exceptions
 * simplifies the error checking.
 */
public errordomain Charango.ParseError {
	PARSE_ERROR,
	ONTOLOGY_ERROR,
	INVALID_URI,
	DUPLICATED_ONTOLOGY,
	UNKNOWN_NAMESPACE
}

/* FIXME: some parse errors should be in herE */
public errordomain Charango.OntologyError {
	UNKNOWN_PROPERTY,
	TYPE_MISMATCH
}

/**
 * Charango.Warning:
 * 
 * Returned by some parse methods when non-fatal errors are discovered while
 * parsing. The caller may choose to ignore these or alert the user.
 */
[Compact]
public class Charango.Warning {
	public string message;

	public Warning (string _message,
	                ...) {
		var va = va_list();
		message = _message.vprintf (va);
	}
}

namespace Charango {

public void print_warnings (List<Warning> warning_list) {
	foreach (unowned Warning w in warning_list)
		print ("Warning: %s\n", w.message);
}

}
