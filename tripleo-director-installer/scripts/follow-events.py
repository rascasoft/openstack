#!/usr/bin/python

import argparse
import logging
import os
import sys
import time
import iso8601

from opensink.openstack import OpenStack
import heatclient.exc


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--verbose', '-v', action='store_const',
                   const='INFO',
                   dest='loglevel')
    p.add_argument('--debug', action='store_const',
                   const='DEBUG',
                   dest='loglevel')
    p.add_argument('--timefmt', '-f',
                   default='%Y-%m-%d %H:%M:%S')
    p.add_argument('--wait', '-w', action='store_true')
    p.add_argument('--marker', '-m')
    p.add_argument('--show-id', '-i', action='store_true')
    p.add_argument('stackid')

    p.set_defaults(loglevel = 'WARN')
    return p.parse_args()


def main():
    args = parse_args()
    logging.basicConfig(level=args.loglevel)
    clients = OpenStack()

    while True:
        try:
            stack = clients.heat.stacks.get(args.stackid)
            break
        except heatclient.exc.HTTPNotFound:
            if not args.wait:
                raise

            logging.info('waiting for stack %s', args.stackid)
            time.sleep(1)

    marker = args.marker
    cols = ['event_time']
    if args.show_id:
        cols.append['event_id']
    cols.extend(['resource_name', 'resource_status', 
                 'resource_status_reason'])

    while True:
        logging.debug('asking for events since %s',
                      marker)

        events = (event.to_dict() for event in
                  clients.heat.events.list(stack.id,
                                           sort_dir='asc',
                                           marker=marker)
                  )

        no_events = True
        for event in events:
            event['event_time'] = iso8601.parse_date(
                event['event_time']).strftime(args.timefmt)
            no_events = False
            print ' '.join(event[col] for col in cols)
            marker = event['id']

        if no_events:
            time.sleep(1)


if __name__ == '__main__':
    main()
