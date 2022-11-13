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
 * $Id: cry.php,v 1.2 2008/04/22 18:52:27 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * CryEngine protocol
 *
 * @author         Tom Buskens <t.buskens@deviation.nl>
 * @version        $Revision: 1.2 $
 */
class GameQ_Protocol_cry extends GameQ_Protocol
{
    public function rules()
    {
        // Header
        $this->header();

        // Rules
        while ($this->p->getLength()) {
            $this->r->add($this->p->readString(), $this->p->readString());
        }
    }

    public function status()
    {
        // Header
        $this->header();

        // Unknown
        $this->p->read(15);

        $this->r->add('hostname', $this->p->readString());
        $this->r->add('mod',      $this->p->readString());
        $this->r->add('gametype', $this->p->readString());
        $this->r->add('map',      $this->p->readString());

        $this->r->add('num_players', $this->p->readInt8());
        $this->r->add('max_players', $this->p->readInt8());
        $this->r->add('password',    $this->p->readInt8());
        $this->p->read(2);
        $this->r->add('punkbuster',  $this->p->readInt8());
    }
    

    public function players()
    {
        $this->header();
        $this->p->skip(2);

        while ($this->p->getLength()) {
            $this->r->addPlayer('name',    $this->p->readString());
            $this->r->addPlayer('team',    $this->p->readString());
            $this->p->skip(1);
            $this->r->addPlayer('score',   $this->p->readInt8());
            $this->p->skip(3);
            $this->r->addPlayer('ping',    $this->p->readInt8());
            $this->p->skip(7);
        }
    }


    private function header()
    {
        if ($this->p->read(4) !== "\x7f\xff\xff\xff") {
            throw new GameQ_ParsingException($this->p);
        }
        $this->p->skip(2);
    }
}
?>

