# Firefox, stripped down: no telemetry, no Pocket, no sponsored tiles, sharp dark UI, uBlock Origin.
{ theme, ... }:
{
  programs.firefox = {
    enable = true;

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFormHistory = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      DisplayBookmarksToolbar = "never";
      OfferToSaveLogins = false;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      FirefoxHome = {
        Search = true;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
      };
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
      };
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.startup.homepage" = "about:blank";
        "browser.newtabpage.enabled" = false;
        "browser.toolbars.bookmarks.visibility" = "never";
        "browser.uidensity" = 1;
        "browser.aboutConfig.showWarning" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.tabs.warnOnClose" = false;
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.suggest.topsites" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "ui.systemUsesDarkTheme" = 1;
        "layout.css.prefers-color-scheme.content-override" = 0;
        "media.ffmpeg.vaapi.enabled" = true;
        "datareporting.healthreport.uploadEnabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        # Fewer writes to the pendrive.
        "browser.cache.disk.enable" = false;
        "browser.sessionstore.interval" = 60000;
      };

      userChrome = ''
        * { border-radius: 0 !important; }

        :root {
          --toolbar-bgcolor: ${theme.surface} !important;
          --tab-selected-bgcolor: ${theme.surfaceAlt} !important;
          --toolbar-field-background-color: ${theme.surfaceAlt} !important;
          --lwt-accent-color: ${theme.surface} !important;
          --lwt-text-color: ${theme.fg} !important;
        }

        #nav-bar { box-shadow: none !important; border: none !important; }

        .tab-background[selected] {
          border-bottom: 2px solid ${theme.primary} !important;
          box-shadow: none !important;
        }

        #urlbar[focused="true"] > #urlbar-background {
          border: 1px solid ${theme.primary} !important;
        }
      '';
    };
  };
}
