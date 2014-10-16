name "buildingagent_web_base"
description "A base role for buildingagent web servers."

run_list([
             "recipe[apache2]",
             "recipe[apache2::mod_ssl]",
             #"recipe[apache2::iptables]",
         ])

override_attributes(
    :apache => {
        :listen_ports => ["80", "443"],
    },
)
