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
 * $Id: tribes2.php,v 1.1 2007/07/07 14:52:01 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Tribes 2 protocol
 *
 * @author         Tom Buskens <t.buskens@deviation.nl>
 * @version        $Revision: 1.1 $
 */
class GameQ_Protocol_tribes2 extends GameQ_Protocol
{
    public function info()
    {
        // Header
        $this->p->skip(6);

        $this->r->add('version', $this->p->readPascalString());

        // TODO: Protocol and build numbers
        $this->p->skip(12);

        $this->r->add('hostname', $this->p->readPascalString());
    }

    public function status()
    {
        // Header
        $this->p->skip(6);

        // Vars
        $this->r->add('mod',         $this->p->readPascalString());
        $this->r->add('gametype',    $this->p->readPascalString());
        $this->r->add('map',         $this->p->readPascalString());
        $this->readBitflag($this->p->read());
        $this->r->add('num_players', $this->p->readInt8());
        $this->r->add('max_players', $this->p->readInt8());
        $this->r->add('num_bots',    $this->p->readInt8());
        $this->r->add('cpu',         $this->p->readInt16());
        $this->r->add('info',        $this->p->readPascalString());

        $this->p->skip(2);

        $this->teams();
        $this->players();
    }

    private function teams()
    {
        $num_teams = $this->p->read();
        $this->r->add('num_teams', $num_teams);
        $this->p->skip();

        for ($i = 0; $i < $num_teams; $i++) {
            $this->r->addTeam('name',  $this->p->readString("\x09"));
            $this->r->addTeam('score', $this->p->readString("\x0a"));
        }
    }

    private function players()
    {
        // TODO
    }


    private function readBitflag($flag)
    {
        $vars = array('dedicated', 'password', 'linux',
                      'tournament', 'no_alias');
        
        $bit = 1;
        foreach ($vars as $var) {
            $value = ($flag & $bit) ? 1 : 0;
            $this->r->add($var, $value);
            $bit *= 2;
        }
    }
}
?>

