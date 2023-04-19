export const options: OptionsListItem[] = [
	{
		name: " --port",
		id: "port",
		param: "--port",
		desc: "Change Backend Port",
		selected: true,
		text: "8083",
		textField: true,
	},
	{
		name: " --lang",
		id: "language",
		param: "--lang",
		desc: "ISO 639-1 codes",
		selected: true,
		default: "en",
		selectField: true,
		text: "en",
	},
	{
		name: " --hostname",
		id: "hostname",
		param: "--hostname",
		desc: "Set hostname",
		selected: false,
		text: "",
		textField: true,
	},
	{
		name: " --email",
		id: "email",
		param: "--email",
		desc: "Set admin email",
		selected: false,
		text: "",
		textField: true,
	},
	{
		name: " --password",
		id: "password",
		param: "--password",
		desc: "Set admin password",
		selected: false,
		text: "",
		textField: true,
	},
	{ name: " --apache", id: "apache", param: "--apache", desc: " Install Apache.", selected: true },
	{ name: " --phpfpm", id: "phpfpm", param: "--phpfpm", desc: "Install PHP-FPM.", selected: true },
	{
		name: " --multiphp",
		id: "multiphp",
		param: "--multiphp",
		desc: " Install Multi-PHP.",
		selected: true,
	},
	{
		name: " --vsftpd",
		id: "vsftpd",
		param: "--vsftpd",
		desc: "Install Vsftpd.",
		selected: true,
		conflicts: "proftpd",
	},
	{
		name: " --proftpd",
		id: "proftpd",
		param: "--proftpd",
		desc: "Install ProFTPD.",
		selected: false,
		conflicts: "vsftpd",
	},
	{ name: " --named", id: "named", param: "--named", desc: "Install Bind.", selected: true },
	{
		name: " --mysql",
		id: "mysql",
		param: "--mysql",
		desc: "Install MariaDB.",
		selected: true,
		conflicts: "mysql8",
	},
	{
		name: " --mysql-classic",
		id: "mysql8",
		param: "--mysql-classic",
		desc: "Install Mysql8.",
		selected: false,
		conflicts: "mysql",
	},
	{
		name: " --postgresql",
		id: "postgresql",
		param: "--postgresql",
		desc: "Install PostgreSQL.",
		selected: false,
	},
	{ name: " --exim", id: "exim", param: "--exim", desc: "Install Exim.", selected: true },
	{
		name: " --dovecot",
		id: "dovecot",
		param: "--dovecot",
		desc: "Install Dovecot.",
		selected: true,
		depends: "exim",
	},
	{
		name: " --sieve",
		id: "sieve",
		param: "--sieve",
		desc: "Enable Dovecot sieve.",
		selected: false,
		depends: "dovecot",
	},
	{
		name: " --clamav",
		id: "clamav",
		param: "--clamav",
		desc: "Install ClamAV.",
		selected: true,
		depends: "exim",
	},
	{
		name: " --spamassassin",
		id: "spamassassin",
		param: "--spamassassin",
		desc: "Install SpamAssassin.",
		selected: true,
		depends: "exim",
	},
	{
		name: " --iptables",
		id: "iptables",
		param: "--iptables",
		desc: "Install Iptables.",
		selected: true,
	},
	{
		name: " --fail2ban",
		id: "fail2ban",
		param: "--fail2ban",
		desc: "Install Fail2ban.",
		selected: true,
	},
	{ name: " --quota", id: "quota", param: "--quota", desc: "Filesystem Quota.", selected: false },
	{ name: " --api", id: "api", param: "--api", desc: "Activate API.", selected: true },
	{
		name: " --interactive",
		id: "interactive",
		param: "--interactive",
		desc: "Interactive install.",
		selected: true,
	},
	{ name: " --force", id: "force", param: "--force", desc: "Force installation.", selected: false },
];
