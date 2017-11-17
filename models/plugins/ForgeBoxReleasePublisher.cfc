component implements="interfaces.ReleasePublisher" {

    property name="versionPrefix"    inject="commandbox:moduleSettings:commandbox-semantic-release:versionPrefix";
    property name="systemSettings"   inject="SystemSettings";
    property name="fileSystemUtil"   inject="FileSystem";
    property name="wirebox"          inject="wirebox";

    public void function run( required string nextVersion ) {

        // set next version
        wirebox.getInstance(
                name = "CommandDSL",
                initArguments = { name = "package version" }
            )
            .params( version = nextVersion )
            .run();

        commitNextVersionToGitHub( nextVersion );

        // publish to ForgeBox
        wirebox.getInstance(
                name = "CommandDSL",
                initArguments = { name = "forgebox publish" }
            )
            .run();
    }

    function commitNextVersionToGitHub( nextVersion ) {
        // The main Git API
        var GitAPI = createObject( 'java', 'org.eclipse.jgit.api.Git' );
        var git = GitAPI.open(
            createObject( 'java', 'java.io.File' ).init( fileSystemUtil.resolvePath( "" ) & ".git" )
        );

        var gitConfig = git.getRepository().getConfig();
        gitConfig.setString( "user", javacast( "null", "" ), "email", "travis@travis-ci.org" );
        gitConfig.setString( "user", javacast( "null", "" ), "name", "Travis CI" );
        gitConfig.save();

        // Add the box.json
        git.add()
            .addFilepattern( 'box.json' )
            .call();

        // Commit the box.json
        git.commit()
            .setMessage( nextVersion )
            .call();

        // Tag this version
        git.tag()
            .setName( '#versionPrefix##nextVersion#' )
            .setMessage( nextVersion )
            .call();

        git.remoteAdd()
            .setName( "origin-travis" )
            .setUri(
                createObject( "java", "org.eclipse.jgit.transport.URIish" )
                    .init( "https://#systemSettings.getSystemSetting( "GH_TOKEN" )#@github.com/#systemSettings.getSystemSetting( "TRAVIS_REPO_SLUG" )#" )
            )
            .call();

        git.push()
            .setRemote( "origin-travis" )
            .add( "master" )
            .call();
    }

}
