# Technology Stack

## Backend
- **Core:** Perl
- **Web Framework:** [Mojolicious](https://mojolicious.org/)
- **Job Queue:** [Minion](https://mojolicious.org/perldoc/Minion)
- **Database Interaction:** [DBIx::Class](https://metacpan.org/pod/DBIx::Class) and [Mojo::Pg](https://metacpan.org/pod/Mojo::Pg)

## Frontend
- **Languages:** JavaScript (ES6+)
- **UI Framework/Libraries:** [Bootstrap](https://getbootstrap.com/), [jQuery](https://jquery.com/)
- **Visualization:** [D3.js](https://d3js.org/)
- **Assets Management:** Mojolicious::Plugin::AssetPack

## Database
- **Primary Database:** [PostgreSQL](https://www.postgresql.org/)

## Infrastructure & DevOps
- **Test Engine:** [os-autoinst](https://github.com/os-autoinst/os-autoinst)
- **Containerization:** Support for Docker, Podman, and Helm charts.
- **CI/CD:** CircleCI (as indicated by `.circleci/config.yml`)
