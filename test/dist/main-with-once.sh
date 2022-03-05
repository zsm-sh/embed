#!/usr/bin/env bash
# {{{ source a.sh
#!/usr/bin/env bash
echo "File a.sh"
# }}} source a.sh
# {{{ source b.sh
#!/usr/bin/env bash
# source a.sh # Embed file already embedded by main.sh
echo "File b.sh"
# }}} source b.sh
# {{{ source c.sh
#!/usr/bin/env bash
# source a.sh # Embed file already embedded by main.sh b.sh
# source b.sh # Embed file already embedded by main.sh
echo "File c.sh"
# }}} source c.sh

#
# c.sh is quoted by main.sh
# b.sh is quoted by main.sh c.sh
# a.sh is quoted by main.sh b.sh c.sh
