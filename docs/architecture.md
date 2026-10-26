# Architecture

Python loads nine source snapshots atomically into stable raw tables. dbt builds staging views, intermediate aggregates and six marts. Metabase consumes the marts. Reloading preserves relation identities and dependent views. The CI checks a reload after a complete build.
