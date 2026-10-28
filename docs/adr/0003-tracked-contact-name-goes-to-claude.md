# The Tracked Contact name goes to the Claude API

ADR 0001 sent only the Transcript to the Claude API, so the Summary called the person "mluvčí" or "odesílatel". Now the request also holds the Tracked Contact name from the configuration. The Summary and Action Items refer to the person by their first name. Czech declines names, for example "Jana", "Janě" and "Janou". Czech verbs also agree with the gender of the person. Only the language model can put the name into correct sentences. The Handles and the audio stay on the Mac.

## Considered Options

- A placeholder that the code replaces with the first name after the Summary returns. Nothing new leaves the Mac. We rejected it because the code cannot decline the name or make the verbs agree with it.
- Only the first name, cut from the Tracked Contact name by the code. The code cannot tell a first name from a role name such as "Mamka". Also, the surname helps Claude find the gender. For these reasons, we rejected it.
