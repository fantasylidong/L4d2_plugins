#if defined _rpg_included
#endinput
#endif
#define _rpg_included

/** 
 * Returns a client have owntags or not.
 *
 * @param        Client Index.
 * @TagType        Tag type.
 * @buffer        String to store the tag in.
 * @maxlength      Maximum size of string buffer.
 *
 * @error        Invalid client index, or not connected.
 */
native int rpg_HaveOwnTags(int client);