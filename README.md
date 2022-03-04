                     __
    ____  ____  ____/ /
   / __ \/ __ \/ __  /
  / /_/ / /_/ / /_/ /
 / .___/\____/\__,_/
/_/


Quickly show available class methods and documentation.


Installation:

   1. Install cpanm.
      cpan App::cpanminus

   2. Install module dependencies.
   cpanm --installdeps .

Usage:

   # Show help.
   pod
   pod -h

Examples:

   # View summary of Mojo::UserAgent:
   pod Mojo::UserAgent

   # View summary of a specific method.
   pod Mojo::UserAgent get

   # Edit the module
   pod Mojo::UserAgent -e

   # Edit the module and jump to the specific method definition right away.
   # (Press "n" to next match if neeeded).
   pod Mojo::UserAgent get -eo

   # Run perldoc on the module (for convience)
   pod Mojo::UserAgent -d

   # List all available methods.
   # If no methods are found normally, then this will automatically be enabled.
   # (pod was made to work with Mojo pod styling).
   pod Mojo::UserAgent -a

