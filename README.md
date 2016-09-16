#Perl Agents

Dieses Repository enthält Perl-Skripten und ein Perl-Modul mit dessen Hilfe Webseiten aus einer Liste aufgerufen und analyisiertw erden können.


## Perl Modul lib/WWWW/Analyse
  
Einfaches Perl Modul zur Analyse von Webseiten  



## get_hochschulen.pl

Ließt die Liste aller Hochschulena us Deutschland aus der Mediawikiseite ein und ruft danach (gecacht und mit einem Delay versehen)
die einzelnen Wikiseiten der Hochschulen auf um aus diesen wiederum weitere Infos abzurufen (wie bsopw. die URL).
Ergebnisse werden in der Datei hochschulen.store gespeichert, bzw. in einer Datei,. die man über Parametereingabe angibt.


## check-hochschulen.pl

Ließt eine Liste von Hochschulen ein (Default: hochschulen.store) und analysiert diese der Reihe nach.
Ergebnisse wreden sowohl in der STore-Datei gespeichert, als auch in einer CSV-Datei, welche nur die aktuellen Namen 
der Hochschulen, die Generatoren und die URLs zeigt.

## check-website.pl

Einfaches Skript um eine Liste von Webseiten oder auch via Parameter  --url=http://www.example.de  zu analysieren.

## read_store.pl

Einfaches perlskript zum Auslesen der Store-Datei
  
