<?php
/**
 * This file is part of GameQ.
 *
 * GameQ is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * GameQ is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * $Id: silverback.php,v 1.1 2007/07/11 09:12:31 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Silverback Engine Protocol
 * (Savage)
 *
 * @author         Tom Buskens    <t.buskens@deviation.nl>
 * @version        $Revision: 1.1 $
 */
class GameQ_Protocol_silverback extends GameQ_Protocol
{
    /*
     * status packet
     */
    public function status()
    {
        while ($this->p->getLength()) {
            $var = $this->p->readString("\xFE");

            if ($var == 'players') break;

            $this->r->add($var, $this->p->readString("\xFF"));
        }

        $this->players();
    }

    /*
     * player / team data
     */
    public function players()
    {
        $team = '';
        $players = 0;
        
        while ($this->p->getLength()) {
            if ($this->p->lookAhead() == "\x20") {
                $this->p->skip();
                $this->r->addPlayer('name', $this->p->readString("\x0a"));
                $this->r->addPlayer('team', $team);
                ++$players;
            }
            else {
                $team = $this->p->readString("\x0a");
                if ($team != '--empty--') {
                    $this->r->addTeam('name', $team);
                }
            }
        }
    }


    /*
     * Merge packets
     */
    public function preprocess($packets)
    {
        // Cut off headers and join packets
        $return = '';

        foreach ($packets as $packet) {
            $return .= substr($packet, 12, strlen($packet) - 13);
        }

        return $return;
    }
}
?>
