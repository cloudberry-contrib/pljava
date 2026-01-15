-- start_ignore
--
-- HOOK NAME: pljava_examples
-- HOOK TYPE: prehook
-- HOOK DESCRIPTION:
--   Install the PL/Java examples jar and set the public classpath when sqlj
--   exists (after CREATE EXTENSION pljava).
--
-- end_ignore

DO $pljava$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'sqlj') THEN
    IF EXISTS (
      SELECT 1
        FROM sqlj.jar_repository
       WHERE jarName = 'examples'
    ) THEN
      PERFORM sqlj.replace_jar(
        'file:///home/gpadmin/workspace/pljava/target/examples.jar',
        'examples',
        false
      );
    ELSE
      PERFORM sqlj.install_jar(
        'file:///home/gpadmin/workspace/pljava/target/examples.jar',
        'examples',
        false
      );
    END IF;

    PERFORM sqlj.set_classpath('public', 'examples');
  END IF;
END
$pljava$;
