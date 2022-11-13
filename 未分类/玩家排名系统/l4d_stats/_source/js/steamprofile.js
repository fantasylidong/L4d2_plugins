/**
 *    Written by Nico Bergemann <barracuda415@yahoo.de>
 *    Copyright 2011 Nico Bergemann
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

jQuery.fn.attrAppend = function(name, value) {
    var elem;
    return this.each(function(){
        elem = $(this);
        
        // append attribute only if extisting and not empty
        if (elem.attr(name) !== undefined && elem.attr(name) != "") {
            elem.attr(name, value + elem.attr(name));
        }
    });
};

function SteamProfile() {
    // path/file config
    var scriptFile = "steamprofile.js";
    var configFile = "steamprofile.xml";
    var proxyFile = "xmlproxy.php";
    var basePath;
    var themePath;
    
    // language config
    var lang = "english";
    var langLocal = "english";
    var langData = {
        english : {
            loading : "Loading...",
            no_profile : "This user has not yet set up their Steam Community profile.",
            private_profile : "This profile is private.",
            invalid_data : "Invalid profile data.",
            add_friend : "Add to friends",
            view_games : "View games",
            view_friends : "View friends",
            view_groups : "View groups",
            view_inventory : "View inventory",
            view_wishlist : "View wishlist",
            view_videos : "View videos",
            view_screenshots : "View screenshots"
        }
    };
    
    // misc config
    var loadLock = false;
    var configLoaded = false;
    var configData;
    var showGameBanner;
    var showSliderMenu;

    // profile data
    var profiles = [];
    var profileCache = {};
    
    // template data
    var profileTpl;
    var loadingTpl;
    var errorTpl;

    this.init = function() {        
        if (typeof spBasePath == "string") {
            basePath = spBasePath;
        } else {
            // extract the path from the src attribute

            // get our <script>-tag
            var scriptElement = $('script[src$=\'' + scriptFile + '\']');
            
            // in rare cases, this script could be included without <script>
            if (scriptElement.length === 0) {
                return;
            }
            
            basePath = scriptElement.attr('src').replace(scriptFile, '');
        }
        
        // load xml config
        jQuery.ajax({
            type: 'GET',
            url: basePath + configFile,
            dataType: 'xml',
            success: function(request, status) {
                configData = $(request);
                loadConfig();
            }
        });
    };
    
    this.refresh = function() {
        // make sure we already got a loaded config
        // and no pending profile loads
        if (!configLoaded || loadLock) {
            return;
        }
        
        // lock loading
        loadLock = true;
        
        // select profile placeholders
        profiles = $('.steamprofile[title]');
        
        // are there any profiles to build?
        if (profiles.length === 0) {
            return;
        }

        // store profile id for later usage
        profiles.each(function() {
            var profile = $(this);
            profile.data('profileID', $.trim(profile.attr('title')));
            profile.removeAttr('title');
        });

        // replace placeholders with loading template and make them visible
        profiles.empty().append(loadingTpl);
        
        // load first profile
        loadProfile(0);
    };
    
    this.load = function(profileID) {
        // make sure we already got a loaded config
        // and no pending profile loads
        if (!configLoaded || loadLock) {
            return null;
        }
        
        // create profile base
        profile = $('<div class="steamprofile"></div>');
        
        // add loading template
        profile.append(loadingTpl);
        
        // load xml data
        jQuery.ajax({
            type: 'GET',
            url: getXMLProxyURL(profileID),
            dataType: 'xml',
            success: function(request, status) {
                // build profile and replace placeholder with profile
                profile.empty().append(createProfile($(request)));
            }
        });
        
        return profile;
    };
    
    this.isLocked = function() {
        return loadLock;
    };
    
    function getXMLProxyURL(profileID) {
        return basePath + proxyFile + '?id=' + escape(profileID) + '&lang=' + escape(lang);
    }
    
    function getConfigString(name) {
        return configData.find('vars > var[name="' + name + '"]').text();
    }
    
    function getConfigBool(name) {
        return getConfigString(name).toLowerCase() == 'true';
    }
    
    function loadConfig() {
        showSliderMenu = getConfigBool('slidermenu');
        showGameBanner = getConfigBool('gamebanner');
        lang = getConfigString('language');
        langLocal = lang;
        
        // fall back to english if no translation is available for the selected language in SteamProfile
        if (langData[langLocal] == null) {
            langLocal = "english";
        }
    
        // set theme stylesheet
        themePath = basePath + 'themes/' + getConfigString('theme') + '/';
        $('head').append('<link rel="stylesheet" type="text/css" href="' + themePath + 'style.css">');
        
        // load templates
        profileTpl = $(jQuery.parseHTML(configData.find('templates > profile').text()));
        loadingTpl = $(jQuery.parseHTML(configData.find('templates > loading').text()));
        errorTpl   = $(jQuery.parseHTML(configData.find('templates > error').text()));
        
        // add theme path to image src
        profileTpl.find('img').attrAppend('src', themePath);
        loadingTpl.find('img').attrAppend('src', themePath);
        errorTpl.find('img').attrAppend('src', themePath);
        
        // use loading template
        loadingTpl.append(langData[langLocal].loading);
        
        // we can now unlock the refreshing function
        configLoaded = true;
        
        // start loading profiles
        SteamProfile.refresh();
    }

    function loadProfile(profileIndex) {
        // check if we have loaded all profiles already
        if (profileIndex >= profiles.length) {
            // unlock loading
            loadLock = false;
            return;
        }
        
        var profile = $(profiles[profileIndex++]);
        var profileID = profile.data('profileID');
        
        if (profileCache[profileID] == null) {
            // load xml data
            jQuery.ajax({
                type: 'GET',
                url: getXMLProxyURL(profileID),
                dataType: 'xml',
                success: function(request, status) {
                    // build profile and cache DOM for following IDs
                    profileCache[profileID] = createProfile($(request));
                    // replace placeholder with profile
                    profile.empty().append(profileCache[profileID]);
                    // load next profile
                    loadProfile(profileIndex);
                }
            });
        } else {
            // the profile was build previously, just copy it
            var profileCopy = profileCache[profileID].clone();
            createEvents(profileCopy);
            profile.empty().append(profileCopy);
            // load next profile
            loadProfile(profileIndex);
        }
    }

    function createProfile(profileData) {
        if (profileData.find('profile').length !== 0) {
            var profile;
            
            var steamID = profileData.find('profile > steamID').text();
            var steamID64 = profileData.find('profile > steamID64').text();
            var customUrl = profileData.find('profile > customURL').text();
            var profileUrl = 'http://steamcommunity.com/profiles/' + steamID64;
            
            if (customUrl.length > 0) {
                profileUrl = 'http://steamcommunity.com/id/' + customUrl;
            }
        
            if (steamID.length == 0) {
                // the profile doesn't exists yet
                return createError(langData[langLocal].no_profile);
            }
            
            // profile data looks good
            profile = profileTpl.clone();
            
            // set state class, avatar image and name
            var onlineState = profileData.find('profile > onlineState').text();
            profile.find('.sp-badge').addClass('sp-' + onlineState);
            profile.find('.sp-avatar img').attr('src', profileData.find('profile > avatarFull').text());
            profile.find('.sp-info a').append(profileData.find('profile > steamID').text());

            // set state message
            var info = profile.find('.sp-info');
            if (profileData.find('profile > visibilityState').text() == '1') {
                info.append(langData[langLocal].private_profile);
            } else {
                info.append(profileData.find('profile > stateMessage').text());
            }

            // set game background
            var gameLogoSmall = profileData.find('profile > inGameInfo > gameLogoSmall').text();
            if (showGameBanner && gameLogoSmall.length > 0) {
                profile.css('background-image', 'url(' + gameLogoSmall + ')');
            } else {
                profile.removeClass('sp-bg-game');
                profile.find('.sp-bg-fade').removeClass('sp-bg-fade');
            }

            if (showSliderMenu) {
                // add button links
                profile.find('.sp-addfriend').attr('href', 'steam://friends/add/' + steamID64);
                profile.find('.sp-addfriend').attr('title', langData[langLocal].add_friend);
                
                profile.find('.sp-viewgames').attr('href', profileUrl + '/games/');
                profile.find('.sp-viewgames').attr('title', langData[langLocal].view_games);
                
                profile.find('.sp-viewfriends').attr('href', profileUrl + '/friends/');
                profile.find('.sp-viewfriends').attr('title', langData[langLocal].view_friends);
                
                profile.find('.sp-viewgroups').attr('href', profileUrl + '/groups/');
                profile.find('.sp-viewgroups').attr('title', langData[langLocal].view_groups);
                
                profile.find('.sp-viewinventory').attr('href', profileUrl + '/inventory/');
                profile.find('.sp-viewinventory').attr('title', langData[langLocal].view_inventory);
                
                profile.find('.sp-viewwishlist').attr('href', profileUrl + '/wishlist/');
                profile.find('.sp-viewwishlist').attr('title', langData[langLocal].view_wishlist);
                
                profile.find('.sp-viewvideos').attr('href', profileUrl + '/videos/');
                profile.find('.sp-viewvideos').attr('title', langData[langLocal].view_videos);
                
                profile.find('.sp-viewscreenshots').attr('href', profileUrl + '/screenshots/');
                profile.find('.sp-viewscreenshots').attr('title', langData[langLocal].view_screenshots);

                createEvents(profile);
            } else {
                profile.find('.sp-extra').remove();
            }

            // add other link hrefs
            profile.find('.sp-avatar a, .sp-info a.sp-name').attr('href', profileUrl);
            
            return profile;
        } else if (profileData.find('response').length !== 0) {
            // steam community returned a message
            return createError(profileData.find('response > error').text());
        } else {
            // we got invalid xml data
            return createError(langData[langLocal].invalid_data);
        }
    }
    
    function createEvents(profile) {
        // add events for menu
        profile.find('.sp-handle').click(function() {
            profile.find('.sp-content').toggle(200);
        });
    }

    function createError(message) {
        var errorTmp = errorTpl.clone();
        errorTmp.append(message);    
        return errorTmp;
    }
}

$(document).ready(function() {
    SteamProfile = new SteamProfile();
    SteamProfile.init();
});