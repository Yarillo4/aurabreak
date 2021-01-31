# AuraBreak Notify

AuraBreak Notify tracks sensitive auras such as sheeps and shackles. It looks for unwanted damage on NPCs that are shackled, sheeped, feared or things of that nature.

Once the addon notices an important buff fading away, it whisps the original spell caster, and tells it "hey, [this guy] broke your [spell], you need to re-cast!"

It also sends a message to the person at fault, telling him "hey, your [attack] faded [some buff]", and to be more careful.

It is rather easy to configure. See "usage".

# Features

* Only **one** member of the raid needs to have this. 
* It is fully based on the combat log
* It works everywhere - but was made with Naxxramas in mind (Gothik's fight).
* Enabled by default for: Polymorph, priest's shackles, hunter's beast fear, druid's hibernate, paladin's undead fear, warlock's single target fear) 
* Can be configured to watch any buff/debuff

# Example

For example, if a Mage casts Polymorph on a Boar and a warrior cleaves it few seconds later, AuraBreak will:

* Whisp the warrior that he just broke Polymorph
* Whisp the mage that his sheep has faded unexpectedly

> To [Caster]: Dpsguy broke your 'Polymorph' on 'Ragged wolf' with 'Shadowbolt'! The aura lasted for 3.24s

> To [Dpsguy]: You broke 'Polymorph' on 'Ragged wolf' with 'Shadowbolt'! The aura lasted for 3.24s.

# Usage

|Command|Description|
|-----|----|
| /abn list | Lists all spells being watched |
| /abn reset | Reset the addon's configs to its defaults |
| /abn watch &lt;spell_name \| spell_id&gt; | Will start watching aura breaks for this spell |
| /abn unwatch &lt;spell_name \| spell_id&gt; | Will stop watching whether or not this aura breaks |
| /abn disable | Disable the addon entirely |
| /abn enable | Enable the addon |
| /abn status [optional subcommand] | Display the current configuration |
| /abn announcements &lt;**off** \| party \| raid \| always&gt; | Configures when to broadcast aura breaks. Default is OFF. I find it distasteful, but it's available anyway.<br>    OFF: Never<br>    PARTY: When in group or in raid (will use /raid if you're in raid, /party if not)<br>    RAID: Only in raid<br>    ALWAYS: Even alone, you will broadcast aurabreaks in /say (note: this API call was protected in 1.13.3, it now only works in dungeons or battlegrounds) |
| /abn warnings &lt;**on** \| off&gt; | Toggles whispering the aura breaker that they broke an aura. |
| /abn denunciation &lt;**on** \| off&gt; | Toggles whispering to the original caster of an important aura that his spell broke. |
| /abn no_whisp &lt;warnings \| denunciations&gt; &lt;name&gt; \[remove\] | Add people to your 'no whisp' list. You can remove them later by adding 'remove' at the end of the command. |
| /abn death_reset &lt;**on** \| off&gt; | Toggles messages for auras broken by the death of an NPC. You probably want this ON, turning it off is a niche use. Mainly for debugging purposes. |
| /abn help | Gives detailed instructions about a /abn command |



