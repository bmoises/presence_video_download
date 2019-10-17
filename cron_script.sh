. $HOME/.profile 
mkdir -p $HOME/presence
cd $HOME/presence
time /usr/bin/ruby presence.rb >> presence.log
date >> presence.log
